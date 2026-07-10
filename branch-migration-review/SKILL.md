---
name: branch-migration-review
description: >
  Bir git branch'ini main (veya belirtilen bir base branch) ile karşılaştırıp
  branch'teki değişiklikleri üç açıdan değerlendirir: (1) DB migration gerekiyor mu,
  (2) yeni bir configuration/settings modeli eklenmişse DB seed gerekiyor mu,
  (3) API/breaking change var mı. Kullanıcı "şu branch'i incele", "bu PR migration
  gerektiriyor mu", "branch'i main ile karşılaştır", "deploy öncesi migration/seed
  kontrolü yap", "bu değişiklikler breaking change mi" gibi bir şey söylediğinde,
  ya da bir branch adı verip "review et" / "analiz et" dediğinde bu skill'i kullan.
  Analiz bittikten sonra kullanıcı onaylarsa GitHub CLI (gh) ile hedef branch'e PR
  açmayı da yapar.
---

# Branch Migration Review

Bu skill'in amacı: bir feature branch'in main'e (ya da başka bir base branch'e) göre
diff'ine bakıp, deploy öncesi insanların gözden kaçırdığı üç riski erken yakalamak.
Kod incelemesi değil, **operasyonel risk taraması** yapıyorsun — "bu branch merge
edilirse elle yapılması gereken bir şey var mı" sorusuna cevap arıyorsun.

## Adım 1 — Girdileri netleştir

İhtiyacın olanlar:
- **Analiz edilecek branch** (kullanıcı verecek).
- **Base branch** — belirtilmediyse `main` varsay, ama repo'da `main` yoksa
  (`master`, `develop` vb. olabilir) kullanıcıya sormadan önce `git branch -a`
  ile kontrol et.
- Çalıştığın yerin bir git reposu olduğundan emin ol (`git rev-parse --is-inside-work-tree`).
  Değilse kullanıcıdan repo'yu bağlamasını / doğru klasörde çalıştığından emin
  olmasını iste.

## Adım 2 — Diff'i topla

Ham `git diff` çıktısını satır satır okumak yerine, önce `scripts/gather_diff.sh`
betiğini çalıştır. Bu betik sana değişen dosyaların listesini, tam diff'i ve
migration/config/API kalıplarına uyan dosyaları önceden kategorize edilmiş
şekilde verir — analiz için başlangıç noktası budur, ama körü körüne bu
kategorilere güvenme, diff içeriğini kendin de oku.

```bash
bash scripts/gather_diff.sh <base-branch> <branch>
```

Repo GitHub'daysa ve branch uzakta (origin) ise, betikten önce `git fetch origin`
çalıştırman gerekebilir; betik bunu otomatik dener ama başarısız olursa elle
fetch et.

## Adım 3 — Üç açıdan analiz et

Her biri için diff'te somut kanıt ara. Şüpheli ama emin olamadığın durumları da
belirt — "gerekmiyor" demek yerine "büyük ihtimalle gerekmiyor, şunu kontrol et"
demek daha güvenli.

### 1) DB migration gerekiyor mu?

Şunlara bak:
- ORM model/entity dosyalarında yeni alan, yeni tablo, tip değişikliği, ilişki
  değişikliği var mı (Django models.py, Rails app/models, SQLAlchemy/Alembic
  models, Prisma schema.prisma, TypeORM entities, GORM structs, vb.)?
- Bu değişikliğe karşılık gelen bir migration dosyası da eklenmiş mi
  (migrations/, db/migrate/, alembic/versions/, prisma/migrations/ gibi
  klasörlerde yeni dosya var mı)?
- Model değişmiş ama migration dosyası yoksa → migration gerekiyor ama eksik,
  bunu net şekilde belirt.
- Migration dosyası da eklenmişse → migration zaten yapılmış, bunu doğrula ve
  içeriğinin model değişikliğiyle tutarlı olup olmadığına kısaca bak.
- Ham SQL dosyaları (schema.sql, .sql migration dosyaları) değişmişse de dahil et.

### 2) Configuration modeli eklenmiş mi, seed gerekiyor mu?

Şunlara bak:
- İsminde/işlevinde "config", "setting", "feature flag", "parameter" gibi
  kavramlar geçen yeni bir model/tablo eklenmiş mi?
- Eklendiyse, bu modelin çalışması için varsayılan satırlara ihtiyaç var mı gibi
  duruyor mu? İpuçları: kodun bu tabloya sabit bir key/ID ile referans vermesi,
  NOT NULL zorunlu alanlar, "ilk kayıt yoksa uygulama patlar" tarzı bir bağımlılık,
  ya da diff içinde zaten bir seed/fixture dosyasının da eklenmiş olması.
- Seed dosyası diff'te zaten varsa → gerekiyordu ve yapılmış, bunu belirt.
- Seed dosyası yoksa ama ihtiyaç sinyali güçlüyse → seed gerekiyor ama eksik,
  net şekilde belirt.

### 3) API/breaking change var mı?

Şunlara bak:
- Public endpoint/route tanımları (controller, router, view fonksiyonları)
  değişmiş mi — path, method, request/response şekli?
- Serializer/DTO/schema (Pydantic, Zod, protobuf, OpenAPI/Swagger dosyası,
  GraphQL schema) içinde alan silinmiş/yeniden adlandırılmış/tipi değişmiş mi?
- Public fonksiyon/metot imzaları (parametre eklenmiş/çıkarılmış, dönüş tipi
  değişmiş) değişmiş mi, özellikle başka servislerin/paketlerin çağırdığı yerler?
- Sadece yeni, geriye dönük uyumlu bir alan/endpoint eklenmişse bu breaking
  değildir — bunu ayırt et.

## Adım 4 — Raporu sun

Kullanıcı "basit cümleler ile sıra sıra" istiyor — uzun bir rapor formatı değil,
üç kısa, net cümle (gerekirse her birine 1 ek açıklama cümlesi). Şuna benzer:

```
1. DB migration: Evet, gerekiyor. `User` modeline `phone_number` alanı eklenmiş
   ama migration dosyası yok.
2. Configuration modeli: Hayır, yeni bir config modeli eklenmemiş.
3. API/breaking change: Evet, `/api/v1/orders` endpoint'inde `status` alanının
   tipi string'den enum'a değişmiş, bu mevcut istemcileri kırabilir.
```

Emin olmadığın noktaları "kontrol et" diye ayrıca belirt, ama üç maddelik ana
yapıyı boz-ma.

## Adım 5 — PR açma (onay sonrası)

Raporu sunduktan sonra PR açmadan önce mutlaka kullanıcıdan onay al ve hedef
(base) branch'i sor — bu her seferinde değişebilir, main olduğunu varsayma.

Onay geldikten sonra:
1. `gh auth status` ile gh CLI'ın kurulu ve login olduğunu doğrula; değilse
   kullanıcıya söyle ve dur.
2. Analiz edilen branch'in push edilmiş/güncel olduğundan emin ol
   (`git push` gerekebilir, kullanıcıya sormadan push etme — sadece iste).
3. PR'ı aç:
   ```bash
   gh pr create --base <hedef-branch> --head <analiz-edilen-branch> \
     --title "<kısa özet>" --body "<Adım 4'teki 3 maddelik analiz>"
   ```
4. PR body'sine Adım 4'teki analiz raporunu aynen koy — bu, reviewer'ların
   migration/seed/breaking change riskini PR açılır açılmaz görmesini sağlar.
5. Oluşan PR linkini kullanıcıya ver.

## Notlar

- Bu skill kod kalitesi/style incelemesi yapmaz — sadece bu üç operasyonel
  riski arar. Başka bulgular fark edersen kısaca ekleyebilirsin ama ana odak
  bu üçü olmalı.
- Repo GitHub değilse (GitLab/Bitbucket) `gh pr create` çalışmaz — kullanıcıya
  bunu söyle ve PR linkini/komutunu manuel oluşturması için diff ve analiz
  raporunu ver.
