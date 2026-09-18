# 会员方案与购买流程

## 当前展示策略

- 唯一方案列表：`PurchaseStoreID.paywallProducts`，依次为 Monthly、Annual、lifetime198、lifetime298。
- 引导页推荐 Annual，展示 StoreKit 返回的完整年费；可查看全部方案、恢复购买或跳过。
- lifetime198 是个人终身，lifetime298 是家庭共享终身。两个现有产品 ID 保持不变，数字不是当前售价。
- 付费墙采用左侧标题/可选副标题、右侧商店价格的紧凑布局；个人终身显示红底白字“最推荐”，家庭终身固定在最后，并在分组底部说明最多 6 位家庭成员共享。
- Weekly 不出现在销售列表里，但原订阅的识别、到期状态、恢复购买和历史记录继续支持。
- Pro 使用统一的 `UserInfoManager.isVIP()`，仍自带高级功能，不展示购买引导。
- 已购终身用户不再被引导购买订阅；个人终身用户仍可主动购买家庭共享终身方案，价格为该商品完整售价，不是差价升级。

## 价格和权益

应用不制造价格、不展示倒计时、不比较两个不同终身商品的“折扣”。所有金额来自 StoreKit。

月度副标题默认为空；年度副标题默认显示商店价格折算的月均价。只有商品配置了真实免费试用，并且 RevenueCat 返回当前用户符合介绍优惠资格，才优先显示本地化的实际试用时长。资格未知/不符合时不承诺免费试用；两个终身商品不显示副标题。购买区继续保留计费说明；引导页仍展示标准年费，具体资格与结算以 Apple 购买确认页为准。

RevenueCat `premium` entitlement 是权益来源，包括符合条件的家庭共享交易。订阅使用 `EntitlementInfo.isActive` 判断有效性，保留宽限期；取消续订不被当作立即退款。启动时读取 CustomerInfo，手动恢复入口才发起 restorePurchases。

到期日期写入 Unix 秒；读取兼容旧版毫秒缓存，避免显示为 1970 年。删除的倒计时缓存不再读取，不影响任何购买凭证。

## 发布前后台核对

1. 在 App Store Connect 配置 Monthly 的真实价格、可售地区及订阅组；在 RevenueCat 中将 `com.OfflineMusic.www.Monthly` 关联到原有 `premium` entitlement。
2. 确认 `lifetime298` 的家庭共享已在 App Store Connect 开启，并仍关联 `premium`；保留所有旧商品/权益映射。
3. 按 [产品本地化表](PurchaseProductLocalizations.md) 更新后台名称和描述。可使用 [受限范围的同步工具](AppStoreConnectPurchaseSync.md)；应用中的 String Catalog 不会自动更新 Apple 购买确认页的商品元数据。
4. Weekly 仅在 App 内取消推荐，本次没有删除后台商品或取消任何老用户订阅。
5. 使用沙盒分别验证四种购买、取消、恢复、订阅续期/过期，以及家庭成员恢复的到账结果。本次没有发起实际购买。

## 本地验证

```sh
ruby Tests/Purchase/check-policy.rb
ruby Tests/Purchase/check-localizations.rb
ruby Tests/Purchase/check-subtitles.rb
ruby Tests/Purchase/check-asc-sync.rb
bash Tests/Purchase/run-price-cell-layout.sh
# 可选：独立渲染真实 Cell，不启动应用、不购买、不读取商店价格
bash Tests/Purchase/run-price-cell-layout.sh --render /private/tmp/purchase-cells.png
```

`StoreKitTest.storekit` 保留旧 Weekly 测试商品，补充 Monthly，更新两个终身商品身份和家庭共享标记。该文件内的金额都是本地测试夹具（Monthly 为 4.99），不是线上定价；不改变 Xcode scheme 的 StoreKit 配置选择。
