# 内购产品本地化资料

本表与应用内 `Localizable.xcstrings` 的 `Purchase.*.Title` / `Purchase.*.Description` 保持一致，覆盖项目现有 42 个语言区域、4 个产品。实际价格由 StoreKit 返回，本表不填写价格、不承诺免费试用，也不把两个终身产品当作同一产品的原价与折扣价。

## 产品映射

| 商品 | 代码枚举 | App Store 产品 ID | 计费方式 |
| --- | --- | --- | --- |
| 月度高级版 | `monthly` | `com.OfflineMusic.www.Monthly` | 按月自动续订 |
| 年度高级版 | `yearly` | `com.OfflineMusic.www.Annual` | 按年自动续订 |
| 终身高级版 | `lifetime198` | `com.OfflineMusic.www.lifetime198` | 一次性购买 |
| 家庭共享终身高级版 | `lifetime298` | `com.OfflineMusic.www.lifetime298` | 一次性购买，支持家人共享 |

`Weekly` 仅保留已有订单识别、权益与恢复兼容，不再展示或推荐。`lifetime198` 和 `lifetime298` 保留原商品 ID；这里的数字不是当前价格，也不会要求老用户重新购买。

## 填写说明

每个标题均为 2–30 个字符，每条描述均不超过 45 个字符，符合 Apple 的[内购本地化元数据长度限制](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information)。描述供 App Store Connect 填写；应用内另外展示 StoreKit 实际总价和计费周期。家庭共享以后台已开启及 Apple 家庭共享规则为准。

下方覆盖应用的全部语言区域。App Store Connect 并不为每个应用 locale 提供独立的商品本地化选项；在后台选择可用的对应语言，无法单独选择的区域使用该语言的基础版本即可，不要创建不存在的区域。

Onboarding 默认推荐年度高级版：先展示完整年费及按年续订说明，并保留查看全部方案、恢复购买及跳过入口。月度方案适合先体验，两个终身方案提供长期使用与家人共享选择。不使用倒计时、虚构划线原价或“仅此一次”提示。

## 标题和描述

### العربية（ar）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | بريميوم شهري | كل ميزات بريميوم. دفع شهري. |
| `Annual` | بريميوم سنوي | كل ميزات بريميوم. دفع سنوي. |
| `Lifetime` | بريميوم مدى الحياة | كل ميزات بريميوم. شراء لمرة واحدة. |
| `FamilyLifetime` | بريميوم عائلي مدى الحياة | بريميوم مدى الحياة مع المشاركة العائلية. |

### Català（ca）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium mensual | Totes les funcions Premium. Pagament mensual. |
| `Annual` | Premium anual | Totes les funcions Premium. Pagament anual. |
| `Lifetime` | Premium de per vida | Totes les funcions Premium. Compra única. |
| `FamilyLifetime` | Premium familiar de per vida | Premium de per vida amb En família. |

### Čeština（cs）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Měsíční Premium | Všechny funkce Premium. Platba měsíčně. |
| `Annual` | Roční Premium | Všechny funkce Premium. Platba ročně. |
| `Lifetime` | Doživotní Premium | Všechny funkce Premium. Jednorázový nákup. |
| `FamilyLifetime` | Rodinné doživotní Premium | Doživotní Premium s Rodinným sdílením. |

### Dansk（da）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Månedlig Premium | Alt i Premium. Månedlig betaling. |
| `Annual` | Årlig Premium | Alt i Premium. Årlig betaling. |
| `Lifetime` | Premium på livstid | Alt i Premium. Engangskøb. |
| `FamilyLifetime` | Familie-Premium på livstid | Premium på livstid med Familiedeling. |

### Deutsch（de）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium monatlich | Alle Premium-Funktionen. Monatliche Zahlung. |
| `Annual` | Premium jährlich | Alle Premium-Funktionen. Jährliche Zahlung. |
| `Lifetime` | Premium auf Lebenszeit | Alle Premium-Funktionen. Einmalzahlung. |
| `FamilyLifetime` | Premium Familie auf Lebenszeit | Premium auf Lebenszeit mit Familienfreigabe. |

### Ελληνικά（el）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Μηνιαίο Premium | Όλες οι λειτουργίες Premium. Μηνιαία χρέωση. |
| `Annual` | Ετήσιο Premium | Όλες οι λειτουργίες Premium. Ετήσια χρέωση. |
| `Lifetime` | Ισόβιο Premium | Όλες οι λειτουργίες Premium. Εφάπαξ αγορά. |
| `FamilyLifetime` | Ισόβιο οικογενειακό Premium | Ισόβιο Premium με Οικογενειακή κοινή χρήση. |

### English（en）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Monthly Premium | All Premium features. Billed monthly. |
| `Annual` | Annual Premium | All Premium features. Billed annually. |
| `Lifetime` | Lifetime Premium | All Premium features. One-time purchase. |
| `FamilyLifetime` | Family Lifetime Premium | Lifetime Premium with Family Sharing. |

### English (Australia)（en-AU）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Monthly Premium | All Premium features. Billed monthly. |
| `Annual` | Annual Premium | All Premium features. Billed annually. |
| `Lifetime` | Lifetime Premium | All Premium features. One-time purchase. |
| `FamilyLifetime` | Family Lifetime Premium | Lifetime Premium with Family Sharing. |

### English (United Kingdom)（en-GB）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Monthly Premium | All Premium features. Billed monthly. |
| `Annual` | Annual Premium | All Premium features. Billed annually. |
| `Lifetime` | Lifetime Premium | All Premium features. One-time purchase. |
| `FamilyLifetime` | Family Lifetime Premium | Lifetime Premium with Family Sharing. |

### English (India)（en-IN）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Monthly Premium | All Premium features. Billed monthly. |
| `Annual` | Annual Premium | All Premium features. Billed annually. |
| `Lifetime` | Lifetime Premium | All Premium features. One-time purchase. |
| `FamilyLifetime` | Family Lifetime Premium | Lifetime Premium with Family Sharing. |

### Español（es）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium mensual | Todas las funciones Premium. Pago mensual. |
| `Annual` | Premium anual | Todas las funciones Premium. Pago anual. |
| `Lifetime` | Premium de por vida | Todas las funciones Premium. Compra única. |
| `FamilyLifetime` | Premium familiar de por vida | Premium de por vida con En Familia. |

### Español (Latinoamérica)（es-419）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium mensual | Todas las funciones Premium. Pago mensual. |
| `Annual` | Premium anual | Todas las funciones Premium. Pago anual. |
| `Lifetime` | Premium de por vida | Todas las funciones Premium. Compra única. |
| `FamilyLifetime` | Premium familiar de por vida | Premium de por vida con Compartir en familia. |

### Español (Estados Unidos)（es-US）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium mensual | Todas las funciones Premium. Pago mensual. |
| `Annual` | Premium anual | Todas las funciones Premium. Pago anual. |
| `Lifetime` | Premium de por vida | Todas las funciones Premium. Compra única. |
| `FamilyLifetime` | Premium familiar de por vida | Premium de por vida con Compartir en familia. |

### Suomi（fi）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Kuukausittainen Premium | Kaikki Premium-toiminnot. Kuukausilaskutus. |
| `Annual` | Vuosittainen Premium | Kaikki Premium-toiminnot. Vuosilaskutus. |
| `Lifetime` | Pysyvä Premium | Kaikki Premium-toiminnot. Kertaostos. |
| `FamilyLifetime` | Pysyvä perhe-Premium | Pysyvä Premium perhejaolla. |

### Français（fr）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium mensuel | Premium complet, facturé chaque mois. |
| `Annual` | Premium annuel | Premium complet, facturé chaque année. |
| `Lifetime` | Premium à vie | Toutes les fonctions Premium. Achat unique. |
| `FamilyLifetime` | Premium à vie en famille | Premium à vie avec le partage familial. |

### Français (Canada)（fr-CA）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium mensuel | Premium complet, facturé chaque mois. |
| `Annual` | Premium annuel | Premium complet, facturé chaque année. |
| `Lifetime` | Premium à vie | Toutes les fonctions Premium. Achat unique. |
| `FamilyLifetime` | Premium à vie en famille | Premium à vie avec le partage familial. |

### עברית（he）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium חודשי | כל תכונות Premium. חיוב חודשי. |
| `Annual` | Premium שנתי | כל תכונות Premium. חיוב שנתי. |
| `Lifetime` | Premium לכל החיים | כל תכונות Premium. רכישה חד־פעמית. |
| `FamilyLifetime` | Premium משפחתי לכל החיים | Premium לכל החיים עם שיתוף משפחתי. |

### हिन्दी（hi）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | मासिक प्रीमियम | सभी प्रीमियम फ़ीचर। मासिक भुगतान। |
| `Annual` | वार्षिक प्रीमियम | सभी प्रीमियम फ़ीचर। वार्षिक भुगतान। |
| `Lifetime` | आजीवन प्रीमियम | सभी प्रीमियम फ़ीचर। एक बार खरीदें। |
| `FamilyLifetime` | आजीवन पारिवारिक प्रीमियम | पारिवारिक साझेदारी के साथ आजीवन प्रीमियम। |

### Hrvatski（hr）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Mjesečni Premium | Sve značajke Premiuma. Mjesečna naplata. |
| `Annual` | Godišnji Premium | Sve značajke Premiuma. Godišnja naplata. |
| `Lifetime` | Doživotni Premium | Sve značajke Premiuma. Jednokratna kupnja. |
| `FamilyLifetime` | Doživotni obiteljski Premium | Doživotni Premium uz Dijeljenje s obitelji. |

### Magyar（hu）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Havi Premium | Minden Premium funkció. Havi számlázás. |
| `Annual` | Éves Premium | Minden Premium funkció. Éves számlázás. |
| `Lifetime` | Örökös Premium | Minden Premium funkció. Egyszeri vásárlás. |
| `FamilyLifetime` | Örökös családi Premium | Örökös Premium Családi megosztással. |

### Bahasa Indonesia（id）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium Bulanan | Semua fitur Premium. Tagihan bulanan. |
| `Annual` | Premium Tahunan | Semua fitur Premium. Tagihan tahunan. |
| `Lifetime` | Premium Seumur Hidup | Semua fitur Premium. Sekali beli. |
| `FamilyLifetime` | Premium Seumur Hidup Keluarga | Premium seumur hidup dengan Keluarga Berbagi. |

### Italiano（it）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium mensile | Tutte le funzioni Premium. Pagamento mensile. |
| `Annual` | Premium annuale | Tutte le funzioni Premium. Pagamento annuale. |
| `Lifetime` | Premium a vita | Tutte le funzioni Premium. Acquisto unico. |
| `FamilyLifetime` | Premium famiglia a vita | Premium a vita con In famiglia. |

### 日本語（ja）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | 月額プレミアム | すべてのプレミアム機能を利用できます。月額課金。 |
| `Annual` | 年額プレミアム | すべてのプレミアム機能を利用できます。年額課金。 |
| `Lifetime` | 永久プレミアム | すべてのプレミアム機能を利用できる買い切りプラン。 |
| `FamilyLifetime` | ファミリー共有の永久プレミアム | ファミリー共有に対応した永久プレミアム。 |

### 한국어（ko）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | 월간 프리미엄 | 모든 프리미엄 기능. 매월 결제됩니다. |
| `Annual` | 연간 프리미엄 | 모든 프리미엄 기능. 매년 결제됩니다. |
| `Lifetime` | 평생 프리미엄 | 한 번 구매로 모든 프리미엄 기능을 이용하세요. |
| `FamilyLifetime` | 가족 공유 평생 프리미엄 | 가족 공유를 지원하는 평생 프리미엄. |

### Bahasa Melayu（ms）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium Bulanan | Semua ciri Premium. Bil bulanan. |
| `Annual` | Premium Tahunan | Semua ciri Premium. Bil tahunan. |
| `Lifetime` | Premium Sepanjang Hayat | Semua ciri Premium. Pembelian sekali sahaja. |
| `FamilyLifetime` | Premium Keluarga Seumur Hidup | Premium seumur hidup. Perkongsian Keluarga. |

### Norsk bokmål（nb）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Månedlig Premium | Alt i Premium. Månedlig betaling. |
| `Annual` | Årlig Premium | Alt i Premium. Årlig betaling. |
| `Lifetime` | Livstids-Premium | Alt i Premium. Engangskjøp. |
| `FamilyLifetime` | Livstids-Premium for familien | Livstids-Premium med Familiedeling. |

### Nederlands（nl）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium per maand | Alle Premium-functies. Maandelijks betaald. |
| `Annual` | Premium per jaar | Alle Premium-functies. Jaarlijks betaald. |
| `Lifetime` | Levenslang Premium | Alle Premium-functies. Eenmalige aankoop. |
| `FamilyLifetime` | Levenslang Premium voor gezin | Levenslang Premium met Delen met gezin. |

### Polski（pl）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium miesięczny | Wszystkie funkcje Premium. Opłata miesięczna. |
| `Annual` | Premium roczny | Wszystkie funkcje Premium. Opłata roczna. |
| `Lifetime` | Premium na zawsze | Wszystkie funkcje Premium. Zakup jednorazowy. |
| `FamilyLifetime` | Rodzinny Premium na zawsze | Premium na zawsze z Chmurą rodzinną. |

### Português (Brasil)（pt-BR）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium mensal | Todos os recursos Premium. Cobrança mensal. |
| `Annual` | Premium anual | Todos os recursos Premium. Cobrança anual. |
| `Lifetime` | Premium vitalício | Todas as funções Premium. Compra única. |
| `FamilyLifetime` | Premium vitalício familiar | Premium vitalício. Compartilhamento Familiar. |

### Português (Portugal)（pt-PT）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium mensal | Todas as funções Premium. Pagamento mensal. |
| `Annual` | Premium anual | Todas as funções Premium. Pagamento anual. |
| `Lifetime` | Premium vitalício | Todas as funções Premium. Compra única. |
| `FamilyLifetime` | Premium vitalício familiar | Premium vitalício com Partilha com a família. |

### Română（ro）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium lunar | Toate funcțiile Premium. Plată lunară. |
| `Annual` | Premium anual | Toate funcțiile Premium. Plată anuală. |
| `Lifetime` | Premium pe viață | Toate funcțiile Premium. Achiziție unică. |
| `FamilyLifetime` | Premium familial pe viață | Premium pe viață cu Partajare familială. |

### Русский（ru）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium на месяц | Все функции Premium. Ежемесячная оплата. |
| `Annual` | Premium на год | Все функции Premium. Ежегодная оплата. |
| `Lifetime` | Premium навсегда | Все функции Premium. Разовая покупка. |
| `FamilyLifetime` | Семейный Premium навсегда | Premium навсегда с Семейным доступом. |

### Slovenčina（sk）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Mesačné Premium | Všetky funkcie Premium. Mesačná platba. |
| `Annual` | Ročné Premium | Všetky funkcie Premium. Ročná platba. |
| `Lifetime` | Doživotné Premium | Všetky funkcie Premium. Jednorazový nákup. |
| `FamilyLifetime` | Rodinné doživotné Premium | Doživotné Premium s Rodinným zdieľaním. |

### Slovenščina（sl）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Mesečni Premium | Vse funkcije Premium. Mesečno plačilo. |
| `Annual` | Letni Premium | Vse funkcije Premium. Letno plačilo. |
| `Lifetime` | Doživljenjski Premium | Vse funkcije Premium. Enkratni nakup. |
| `FamilyLifetime` | Družinski Premium za vedno | Premium za vedno z Družinsko skupno rabo. |

### Svenska（sv）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium månadsvis | Alla Premium-funktioner. Månadsbetalning. |
| `Annual` | Premium årsvis | Alla Premium-funktioner. Årsbetalning. |
| `Lifetime` | Premium på livstid | Alla Premium-funktioner. Engångsköp. |
| `FamilyLifetime` | Familje-Premium på livstid | Premium på livstid med Familjedelning. |

### ไทย（th）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | พรีเมียมรายเดือน | ครบทุกฟีเจอร์พรีเมียม ชำระรายเดือน |
| `Annual` | พรีเมียมรายปี | ครบทุกฟีเจอร์พรีเมียม ชำระรายปี |
| `Lifetime` | พรีเมียมตลอดชีพ | ครบทุกฟีเจอร์พรีเมียม ซื้อครั้งเดียว |
| `FamilyLifetime` | พรีเมียมตลอดชีพแบบครอบครัว | พรีเมียมตลอดชีพพร้อมการแชร์กันในครอบครัว |

### Türkçe（tr）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Aylık Premium | Tüm Premium özellikleri. Aylık ödeme. |
| `Annual` | Yıllık Premium | Tüm Premium özellikleri. Yıllık ödeme. |
| `Lifetime` | Ömür Boyu Premium | Tüm Premium özellikleri. Tek seferlik alım. |
| `FamilyLifetime` | Ömür Boyu Aile Premium | Aile Paylaşımı ile ömür boyu Premium. |

### Українська（uk）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium на місяць | Усі функції Premium. Щомісячна оплата. |
| `Annual` | Premium на рік | Усі функції Premium. Щорічна оплата. |
| `Lifetime` | Premium назавжди | Усі функції Premium. Одноразова покупка. |
| `FamilyLifetime` | Сімейний Premium назавжди | Premium назавжди із Сімейним доступом. |

### Tiếng Việt（vi）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | Premium hằng tháng | Mọi tính năng Premium. Thanh toán hằng tháng. |
| `Annual` | Premium hằng năm | Mọi tính năng Premium. Thanh toán hằng năm. |
| `Lifetime` | Premium trọn đời | Mọi tính năng Premium. Mua một lần. |
| `FamilyLifetime` | Premium gia đình trọn đời | Premium trọn đời với Chia sẻ trong gia đình. |

### 繁體中文（香港）（zh-HK）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | 月費高級版 | 解鎖所有高級功能，按月訂閱。 |
| `Annual` | 年費高級版 | 解鎖所有高級功能，按年訂閱。 |
| `Lifetime` | 終身高級版 | 一次購買，終身解鎖所有高級功能。 |
| `FamilyLifetime` | 家人共享終身高級版 | 終身解鎖所有高級功能，支援家人共享。 |

### 简体中文（zh-Hans）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | 月度高级版 | 解锁所有高级功能，按月订阅。 |
| `Annual` | 年度高级版 | 解锁所有高级功能，按年订阅。 |
| `Lifetime` | 终身高级版 | 一次购买，终身解锁所有高级功能。 |
| `FamilyLifetime` | 家庭共享终身高级版 | 终身解锁所有高级功能，支持家人共享。 |

### 繁體中文（台灣）（zh-Hant）

| 产品 | 本地化标题 | 本地化描述 |
| --- | --- | --- |
| `Monthly` | 月訂閱高級版 | 解鎖所有高級功能，按月訂閱。 |
| `Annual` | 年訂閱高級版 | 解鎖所有高級功能，按年訂閱。 |
| `Lifetime` | 終身高級版 | 一次購買，終身解鎖所有高級功能。 |
| `FamilyLifetime` | 家人共享終身高級版 | 終身解鎖所有高級功能，支援家人共享。 |
