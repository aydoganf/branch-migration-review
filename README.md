# branch-migration-review

Bir git branch'ini `main` (veya belirttiğin başka bir base branch) ile karşılaştırıp
merge öncesi kolay gözden kaçan üç riski kontrol eden bir Claude skill'i:

1. **DB migration gerekiyor mu?** Model/entity dosyalarında değişiklik var ama
   karşılığında migration dosyası yoksa bunu yakalar (Django, Rails, Alembic,
   Prisma, TypeORM, GORM, ham SQL gibi yaygın migration klasörlerini tanır).
2. **Configuration modeli eklendiyse seed gerekiyor mu?** Yeni bir
   config/settings/feature-flag modeli eklenmiş mi, eklendiyse varsayılan
   veriye ihtiyacı var mı diye bakar.
3. **API/breaking change var mı?** Endpoint, route, serializer/DTO veya public
   fonksiyon imzalarındaki geriye dönük uyumsuz değişiklikleri arar.

Analizin sonunda üç kısa cümlelik bir özet verir. Onaylarsan, GitHub CLI (`gh`)
ile senin belirttiğin hedef branch'e PR açar ve analiz özetini PR açıklamasına
koyar.

## Nasıl çalışır

- `scripts/gather_diff.sh <base-branch> <branch>` betiği `git diff` çalıştırır,
  değişen dosyaları migration/model/config/seed/API kalıplarına göre önceden
  kategorize eder.
- Claude bu ön-kategorileri başlangıç noktası olarak kullanır ama diff
  içeriğini de kendisi okuyup gerçek bir değerlendirme yapar — sadece dosya
  adına bakıp karar vermez.
- Repo GitHub'da değilse (GitLab/Bitbucket vb.) PR açma adımı çalışmaz; bu
  durumda analiz raporunu ve diff'i sana verir, PR'ı elle açman gerekir.

## Gereksinimler

- Analiz yapılacak yerin bir git reposu olması (`git rev-parse --is-inside-work-tree`).
- PR açma adımı için [GitHub CLI (`gh`)](https://cli.github.com/) kurulu ve
  `gh auth login` ile giriş yapılmış olmalı.

## Kurulum

Skill'i indirdiğin `branch-migration-review.skill` dosyasını (zip arşivi)
şu iki yerden birine açman yeterli — ayrıca bir kayıt/ayar gerekmez, Claude
Code otomatik keşfeder.

### Global kurulum (tüm repolarda çalışır — önerilen)

```bash
mkdir -p ~/.claude/skills
unzip -o ~/Downloads/branch-migration-review.skill -d ~/.claude/skills/
```

Bu, `~/.claude/skills/branch-migration-review/SKILL.md` ve
`~/.claude/skills/branch-migration-review/scripts/gather_diff.sh` dosyalarını
oluşturur. Kurulumdan sonra hangi repo'da olursan ol skill kullanılabilir.

### Sadece belirli bir repoda kurulum

```bash
cd /yolu/olan/repo
mkdir -p .claude/skills
unzip -o ~/Downloads/branch-migration-review.skill -d .claude/skills/
```

Bu şekilde skill sadece o repo içinde çalışır. `.claude/skills/` klasörünü
git'e commit edersen, repodaki diğer katkıda bulunanlar da otomatik olarak
kullanabilir.

## Kullanım

Cursor içindeki Claude Code terminalinde (veya herhangi bir Claude Code
oturumunda), bir repo içindeyken şöyle bir şey söylemen yeterli:

```
feature/add-phone-number branch'ini main ile karşılaştır, migration/config/breaking
change açısından incele
```

veya kısaca:

```
şu branch'i review et: feature/add-phone-number
```

Claude, analiz sonunda 3 maddelik özeti gösterir. PR açılmasını istiyorsan
hangi hedef branch'e açılacağını belirtip onay vermen yeterli.

## Örnek çıktı

```
1. DB migration: Evet, gerekiyor. `User` modeline `phone_number` alanı eklenmiş
   ama migration dosyası yok.
2. Configuration modeli: Hayır, yeni bir config modeli eklenmemiş.
3. API/breaking change: Evet, `/api/v1/orders` endpoint'inde `status` alanının
   tipi string'den enum'a değişmiş, bu mevcut istemcileri kırabilir.
```

## Sınırlamalar

- Kod kalitesi/style incelemesi yapmaz, sadece bu üç operasyonel riski arar.
- Migration/seed ihtiyacı tespiti sezgisel kalıplara dayanır; kesin bir statik
  analiz değildir, şüpheli durumları "kontrol et" diyerek işaretler.
- PR açma adımı sadece GitHub + `gh` CLI ile çalışır.
