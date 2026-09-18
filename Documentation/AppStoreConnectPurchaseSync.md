# 同步内购商品的本地化名称和描述

脚本：[sync-purchase-localizations.rb](../Tools/AppStoreConnect/sync-purchase-localizations.rb)。仅 Ruby 标准库，不依赖第三方 gem。

## 范围与安全边界

- 固定应用 `6544783918`，按准确 product ID 发现 Monthly、Annual、lifetime198、lifetime298。Monthly 的 ASC ID 另校验为已在后台核实的 `6813533933`。
- 只写各语言的 `name`、`description`；新增缺失语言时同时指定 `locale`。不改价格、优惠、家庭共享开关、订阅组或审核状态，不提交审核、不删除已有语言、不访问 Weekly 的本地化。
- 必须先读取四个商品及其全部本地化，保存 `before.json` 和 `plan.json`，然后显式 `--apply` 才可远程写入。
- 应用级备份只保存 `id`、`type`、`name`、`bundleId`、`sku` 和 `primaryLocale`，不保存无关的回调地址或服务配置。
- `.p8` 仅从指定文件读取，文件必须只有所属用户可访问。不会寻找其他密钥，不写出私钥或 JWT。备份输出目录权限为 `0700`，文件为 `0600`，每次运行使用全新目录，避免覆盖旧备份。
- Apple 的分页链接仅允许 `https://api.appstoreconnect.apple.com:443`，不跟随重定向到其他域名。
- 有限重试 429 和只读 5xx；每次等待最多 10 秒。写入网络错误或 5xx 不自动重试，避免重复创建。失败立即停止，保留已完成操作的 `result.json`；重新 dry-run 可核对实际远端状态。
- 完成写入后重新 GET 全部目标语言核对。API 保存成功不等于 Apple 已审核或已对用户生效。

## 操作

将真实密钥放在仓库外的受限本地目录。不要把私钥内容写在命令行、提交 git 或贴进脚本。

```sh
ruby Tools/AppStoreConnect/sync-purchase-localizations.rb \
  --key-file /private/path/AuthKey.p8 \
  --key-id YOURKEYID1 \
  --issuer-id 00000000-0000-0000-0000-000000000000 \
  --output /private/path/new-dry-run-directory
```

确认 `plan.json` 后，使用新的输出目录加 `--apply`。该轮仍会重新读取和备份最新远端数据，不依赖旧快照盲写。

可用 `--locales en-US,zh-Hans,zh-Hant` 限定本轮要同步的 ASC 语言；未选择的语言保持不变。默认同步 39 个对应语言，另将中性英文明确复用到加拿大英语槽位，共 40 个 ASC 语言。

可用 `--products Lifetime,FamilyLifetime` 只选择这两个产品，或 `--products Lifetime` 只处理个人终身。选项只接受 `Monthly`、`Annual`、`Lifetime`、`FamilyLifetime` 的非空不重复子集，不接受 Weekly 或原始商品 ID。发现、备份、计划、写入和验证都仅针对选中产品；默认仍为四个。如果需要两个独立进程并行，务必使用互不重叠的单产品选择及不同私有输出目录，完成后再对全部四个做只读核对。

## 语言对应

应用内 42 种语言并不等于 ASC 中 42 个元数据槽位。本脚本使用 Apple 官方短码表（2026-09-18 核对），共 39 种有对应项：

| 应用语言 | ASC 语言 |
|---|---|
| `en` | `en-US` |
| `en`（明确复用） | `en-CA`（官方支持；保留后台原有加拿大英语并替换旧文案，也为 Monthly 新增） |
| `ar` | `ar-SA` |
| `de` | `de-DE` |
| `fr` | `fr-FR` |
| `nl` | `nl-NL` |
| `nb` | `no` |
| `sl` | `sl-SI` |
| `es` | `es-ES` |
| `es-419` | `es-MX`（Apple 的西班牙语拉丁美洲元数据槽位） |
| `zh-Hans` / `zh-Hant` | 同名 |
| `en-IN` / `es-US` / `zh-HK` | 无独立对应项，仅保留在应用中，不覆盖其他译文 |
| 其他 28 种 | 同名 |

加拿大英语是有明确依据的中性英语复用，不是应用内新增翻译。`plan.json` 用 `explicitASCFallbacks` 记录此映射。没有为了凑语言数而把印度英语、美国西语、香港繁中映射到重复槽位。既有其他 ASC 语言不删除。

## 官方 API 依据

- [管理内购商品](https://developer.apple.com/documentation/appstoreconnectapi/managing-in-app-purchases)：`GET /v1/apps/{id}/inAppPurchasesV2` 发现非消耗品。
- [订阅组](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-apps-_id_-subscriptiongroups)及[组内订阅](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-subscriptiongroups-_id_-subscriptions)：发现两项自动续期订阅。
- [读取订阅本地化](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-subscriptions-_id_-subscriptionlocalizations)、[更新订阅本地化](https://developer.apple.com/documentation/appstoreconnectapi/patch-v1-subscriptionlocalizations-_id_)：订阅使用 `subscriptionLocalizations`。
- [读取内购本地化](https://developer.apple.com/documentation/appstoreconnectapi/get-v2-inapppurchases-_id_-inapppurchaselocalizations)、[更新内购本地化](https://developer.apple.com/documentation/appstoreconnectapi/patch-v1-inapppurchaselocalizations-_id_)：非消耗品使用 `inAppPurchaseLocalizations`；创建时关系名为 `inAppPurchaseV2`，关系资源类型仍为 `inAppPurchases`。
- [官方 locale 短码](https://developer.apple.com/documentation/appstoreconnectapi/managing-metadata-in-your-app-by-using-locale-shortcodes)。

**默认版本说明：** 2026 年 4.4.1 API 引入 metadata version-based v2，旧本地化端点被标为 deprecated，但 Apple 的迁移文档说明仍为已有集成保留。默认使用现有兼容端点；例如 Monthly 的初始元数据可直接保存。但已生效的 `ACTIVE` 订阅本地化可能返回 `409 Cannot edit SubscriptionLocalization when ACTIVE`，此时不要把其 ID 直接套用到 v2 PATCH。

## 已上线商品的待审核文案草稿

经明确授权可以增加 `--metadata-draft`。单独指定仍然只是 dry-run；与 `--apply` 一起才创建或复用待审核文案草稿。

```sh
ruby Tools/AppStoreConnect/sync-purchase-localizations.rb \
  --key-file /private/path/AuthKey.p8 \
  --key-id YOURKEYID1 \
  --issuer-id 00000000-0000-0000-0000-000000000000 \
  --output /private/path/new-draft-dry-run-directory \
  --metadata-draft
```

这个模式遵循 Apple 的[订阅版本](https://developer.apple.com/documentation/appstoreconnectapi/working-with-subscription-versions)、[内购版本](https://developer.apple.com/documentation/appstoreconnectapi/working-with-in-app-purchase-versions)及[迁移说明](https://developer.apple.com/documentation/appstoreconnectapi/migrating-in-app-purchase-metadata-to-v2)：

1. 先读取 `GET /v1/subscriptions/{id}/versions` 或 `GET /v2/inAppPurchases/{id}/versions`。**不使用旧 parent-level localizations 接口**：迁移后它可能同时返回已批准版和草稿中的同一语言，不能随意去重选择。
2. 备份基准为数字 `version` 最高的 `APPROVED` / `ACCEPTED` 版本；最高版本号重复或不合法时停止。没有已批准版时（例如新 Monthly），以唯一 `PREPARE_FOR_SUBMISSION` 版为基准。唯一的编辑草稿会单独读取/复用；多草稿、`READY_FOR_REVIEW`、`WAITING_FOR_REVIEW` 或 `IN_REVIEW` 时停止，不改变审核流程。
3. 如果目标版本（有草稿时优先草稿，否则已批准版）的 40 个语言完全一致，直接跳过，不制造多余草稿。备份、计划和验证结果仍记录它的 `versionId`、状态及 `metadataDraft` / `approvedVersion` 类型，绝不把草稿标成已发布。
4. 没有草稿时，POST `/v1/subscriptionVersions` 或 `/v1/inAppPurchaseVersions`。`data.type` 分别为 `subscriptionVersions` / `inAppPurchaseVersions`；关系分别为 `subscription` / `inAppPurchase`，关联准确的原商品 ID。不添加属性，也不改变原商品设置。
5. 创建或取得草稿后，重新 GET `/v1/{subscriptionVersions|inAppPurchaseVersions}/{versionID}/localizations`。不假定草稿为空，也不假定 API 自动复制了旧文案。创建请求超时后也必须重新执行只读发现；若实际已创建，则复用该草稿，不能盲目重复 POST。
6. 缺失语言 POST `/v2/{subscriptionLocalizations|inAppPurchaseLocalizations}`，关系为 `version`，其 `data.type` 是对应版本类型；现有草稿语言只 PATCH 相应 v2 localization ID 的 `name`、`description`。
7. 目标范围外的旧语言原样保留。若用户已在现有草稿中编辑其他语言，则保留草稿新文案，不能用线上旧文案覆盖。
8. 写后重新 GET **相同版本**的语言列表，核对所有目标语言及保留语言，并确认版本仍是 `PREPARE_FOR_SUBMISSION`；被跳过的版本也按其精确 ID 验证。

`plan.json` 会列出 `versionOperations`（新建/复用）、预计语言操作，以及 `willSubmitForReview: false`。每个实际草稿另存 `draft-before-产品.json`、`draft-plan-产品.json`，完整记录 API 自动复制后的实际更新计划。

**草稿保存不等于上线。** 本脚本不调用任何 `reviewSubmissions` / `reviewSubmissionItems` 接口，不提交审核，不处理审核图片。用户可在 ASC 确认文案和其他所需材料后自行提交。API 通过后的沙盒展示也可能需要缓存刷新时间。

## 离线测试

```sh
ruby Tests/Purchase/check-asc-sync.rb
```

验证 40 个 ASC 语言元数据长度、加拿大英语新建和更新、exact product 发现、备份权限和字段收敛、dry-run 无写入、Weekly 不受影响、只允许 metadata 字段、写入后读回、幂等重跑和原生 ES256 签名。还验证草稿模式从不读取可能混合多个版本语言的旧接口、按最高数字版本选已批准基准、Monthly 仅有 prepare 版、跳过已同步草稿、复用超时后实际已创建的草稿、拒绝歧义或审核中的版本、应对自动复制的旧元数据、保留其他语言草稿文案，以及绝不修改已上线文案或送审。夹具不连接 Apple，也不包含真实密钥。

## 2026-09-19 实际同步记录

已通过 Apple 官方 API 保存四个商品共 **160 套**名称与描述（每个商品 40 种 ASC 语言）。最终独立只读核验结果为 `unchanged=160`、`versionOperations=[]`，所有目标文案与 String Catalog 一致。

| 商品 | 文案版本 | 状态 |
|---|---|---|
| Monthly | 1 | PREPARE_FOR_SUBMISSION |
| Annual | 2 | PREPARE_FOR_SUBMISSION |
| lifetime198（个人终身） | 2 | PREPARE_FOR_SUBMISSION |
| lifetime298（家庭终身） | 2 | PREPARE_FOR_SUBMISSION |

这是**已保存、未送审的文案草稿**，不是已发布更新。未修改价格、优惠、家庭共享开关、RevenueCat 配置或 Weekly，也未发起购买。用户仍需在 ASC 核对审核材料并自行提交。

两次创建请求返回超时时，均先重新读取准确版本确认实际状态；最终确认请求已在 Apple 端成功完成，没有重复建立草稿或语言记录。

本次原始备份：`/private/tmp/wake-purchase-compact.uc9ETO/asc-apply/before.json`；最终只读核验及完整版本快照：`/private/tmp/wake-purchase-compact.uc9ETO/asc-final-verify/`。这些是本机权限受限的临时路径，可能被系统清理；不含私钥或 JWT。本次临时签名私钥文件已经删除，未写入项目。后续同步应使用用户新提供的本地密钥文件，不保留聊天中提供的凭证。
