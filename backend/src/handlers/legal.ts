// 隐私政策 / 用户协议：静态法律文本页，公开路由不用登录。
// App 注册页链接这两个页面、「我的」设置页常驻入口也链这里；
// 应用商店上架（隐私链接可访问 5.1.1）、App 备案都要用到这两个链接。
//
// ⚠️ 运营主体信息目前是占位——企业资质申请下来之后，把下面 ENTITY 换成
// 企业名称，正文里「个人开发者」的措辞也要一并改成企业名义，别忘了。
import { COL } from '../config';
import { getDb } from '../db';
import { json, Req, Res } from '../http';
import { verifyPassword } from '../password';

const ENTITY = '「人生清单」开发者（个人开发者，企业主体申请中，資質下来后更新本页）';
const UPDATED = '2026-08-17';
/** 网页版注销页（静态托管，源码在仓库 delete/index.html）。
 * Google Play「数据安全」表单里的账号删除网址填的就是这个地址，
 * App Store Connect 的 Account Deletion URL 同。改地址要一起改那两处后台配置。 */
const DELETION_PAGE_URL =
  'https://renshengqingdan-d8feva5q55d12bab-1258070735.tcloudbaseapp.com/account-deletion/';

const STYLE = `
  body { font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Microsoft YaHei", sans-serif;
    max-width: 720px; margin: 0 auto; padding: 32px 20px 80px; color: #1C1C21; line-height: 1.75; }
  h1 { font-size: 22px; margin-bottom: 4px; }
  .meta { color: #8A8C98; font-size: 13px; margin-bottom: 28px; }
  h2 { font-size: 16.5px; margin-top: 30px; margin-bottom: 8px; color: #1C1C21; }
  p, li { font-size: 14.5px; color: #3A3C46; }
  ul { padding-left: 20px; }
  li { margin-bottom: 4px; }
  a { color: #3EA983; }
  .tip { background: #E2F1EA; border-radius: 10px; padding: 12px 14px; font-size: 13.5px; color: #2B7A5C; margin: 16px 0; }
`;

function page(title: string, body: string): Res {
  return {
    statusCode: 200,
    headers: { 'content-type': 'text/html; charset=utf-8' },
    body: `<!doctype html><html lang="zh-CN"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${title} · 人生清单</title><style>${STYLE}</style></head>
<body><h1>${title}</h1><div class="meta">最近更新：${UPDATED}</div>${body}</body></html>`,
  };
}

export async function privacyPage(): Promise<Res> {
  return page(
    '隐私政策',
    `
<p>欢迎使用「人生清单」（以下简称"本 App"）。本 App 由 ${ENTITY} 开发和运营。
我们非常重视你的个人信息保护，制定本政策向你说明我们收集哪些信息、为什么收集、
怎么用、和谁共享，以及你可以怎样管理自己的信息。</p>

<p>使用本 App 前，请你完整阅读本政策；如果你不同意，可以只使用本地预览模式
（见下方"同意流程"），不注册、不登录，我们不会联网、不会采集你的任何信息。</p>

<h2>一、同意流程</h2>
<p>首次打开本 App 时会弹出提示，请你阅读并选择"同意并继续"或"不同意，仅本地使用"：</p>
<ul>
  <li><b>选择不同意</b>：App 停留在本地预览态——可以浏览内置的 50 条人生清单模板，
    但不会联网、不会采集或上传任何信息（包括设备信息、崩溃日志）。之后如果你想登录、
    注册或同步数据，会再次看到这个提示。</li>
  <li><b>选择同意</b>：才会开始联网使用登录、云同步、崩溃上报等功能，也就是本政策第二节
    列出的这些信息类型。</li>
</ul>
<p>除了这次统一的同意之外，涉及系统权限（相机、相册、定位）的功能，还会在第一次触发
时先弹一句场景说明（比如"为了帮你确认打卡地点，需要访问你的位置信息"），说明白了你再
决定是否去系统弹窗里授权——不会不由分说直接弹系统权限框。</p>

<h2>二、我们收集的信息</h2>

<p><b>1. 账号信息</b><br>
你自己设置的账号名（3-20 位字母/数字/下划线，不是手机号）和密码（我们只存储加密后的哈希值，
不存明文，我们自己也看不到你的密码）。</p>

<p><b>2. 你主动填写的资料</b><br>
昵称、头像（可以是内置图案，也可以是你上传的照片）、性别、生日——这几项<b>都不是必填</b>，
不填不影响使用核心功能；生日只用来在你自己的资料页显示年龄。</p>

<p><b>3. 你在 App 里创建的内容</b><br>
心愿（标题、描述、完成状态、里程碑、你写的笔记、你上传的照片）、任务、时光胶囊信件。
这些内容存在云端，是为了让你换设备登录后能看到同一份数据。</p>

<p><b>4. 位置信息</b><br>
仅当你主动点击"打卡"按钮时，我们会通过系统定位获取你当时的位置，用来判断你在哪个
景区/地点，只在这一次点击时取一次位置，不会在后台持续追踪你的位置。你可以随时在
系统设置里关闭定位权限，关闭后仍能使用其它功能，只是不能打卡了。</p>

<p><b>5. 设备与登录日志</b><br>
登录时我们会记录设备型号、操作系统、App 版本号和登录时的 IP 地址，
用于识别异常登录、排查问题，不用于精确定位你的身份。</p>

<p><b>6. 使用行为数据</b><br>
仅在你登录后，我们会记录一些操作事件（比如新增心愿、完成任务、打卡、分享），
不含内容本身，只是"发生了什么类型的操作"，用来了解功能使用情况、改进产品。</p>

<p><b>7. 崩溃与稳定性信息</b><br>
App 出现异常退出或崩溃时，会先把错误类型和代码堆栈（不含你的心愿内容等个人数据）
<b>只写在你自己的设备本地</b>；只有在你同意本政策之后，这些记录才会联网上报给我们
用于定位和修复问题——同意之前产生的崩溃现场也是先存在本地，同意的那一刻才补发，
不会在你同意之前偷偷联网。</p>

<p><b>8. 你主动提交的反馈</b><br>
你在"意见反馈"里写的内容，我们会存下来用于处理你的问题。</p>

<div class="tip">
以上信息全部存储在腾讯云开发（CloudBase）的境内节点，我们不会把你的数据卖给任何第三方，
也不会用于广告投放——本 App 没有接入任何广告 SDK、没有友盟/极光/微信等第三方数据采集
SDK；唯一使用的第三方组件见下方"第三方 SDK 目录"。
</div>

<h2>三、第三方 SDK 目录</h2>
<table style="width:100%;border-collapse:collapse;margin:12px 0;font-size:13.5px">
  <tr style="background:#F7F8FA">
    <th style="text-align:left;padding:6px 8px;border:1px solid #E6E7EC">名称</th>
    <th style="text-align:left;padding:6px 8px;border:1px solid #E6E7EC">用途</th>
    <th style="text-align:left;padding:6px 8px;border:1px solid #E6E7EC">采集的信息</th>
    <th style="text-align:left;padding:6px 8px;border:1px solid #E6E7EC">适用平台</th>
  </tr>
  <tr>
    <td style="padding:6px 8px;border:1px solid #E6E7EC">KSCrash（开源库）</td>
    <td style="padding:6px 8px;border:1px solid #E6E7EC">捕获 App 闪退这类 Dart 层抓不到的原生层崩溃，帮助我们定位修复</td>
    <td style="padding:6px 8px;border:1px solid #E6E7EC">崩溃时的系统调用栈、进程状态等诊断信息，不含你的心愿内容等个人数据；
      同上，先存本地，同意后才随崩溃上报一起联网发送</td>
    <td style="padding:6px 8px;border:1px solid #E6E7EC">仅 iOS</td>
  </tr>
</table>
<p>本 App 不接入其它任何第三方 SDK。以后如果新增会同步更新这份清单。</p>

<h2>四、我们如何使用这些信息</h2>
<ul>
  <li>提供心愿/任务/时光胶囊的记录、同步、提醒等核心功能</li>
  <li>生成排行榜（比如"多少人也想去看海"）——这类统计是聚合数字，不会展示你的具体身份，除非你自己选择公开分享</li>
  <li>排查登录异常、崩溃和故障</li>
  <li>处理你提交的反馈</li>
</ul>

<h2>五、哪些信息可能被其他用户看到</h2>
<p>本 App 有一些"轻社交"功能，使用时请注意：</p>
<ul>
  <li><b>排行榜</b>：昵称、头像、性别角标可能出现在心愿/地点热度榜和用户主页里</li>
  <li><b>个人主页</b>：如果别人知道你的账号对应的主页链接，能看到你的昵称、头像、性别、
    根据生日算出的年龄、以及你的心愿/成就统计数字——<b>如果你不希望年龄被看到，不填生日即可</b></li>
  <li><b>分享卡片</b>：你主动生成的心愿分享链接，打开链接的人能看到卡片上的内容</li>
</ul>
<p>除了以上你主动触发的场景，我们不会把你的账号信息、心愿内容对外公开。</p>

<h2>六、你的权利</h2>
<ul>
  <li><b>查看和修改</b>：昵称、头像、性别、生日都可以在"我的"页面随时改</li>
  <li><b>注销账号</b>：可以在 App 内注销（我的 → 注销账号，立即生效）；已经卸载了 App 的话，
    也可以在网页上提交注销申请：<a href="${DELETION_PAGE_URL}">注销账号</a>
    （验证账号密码确认是本人后受理，我们在 30 天内完成注销）</li>
  <li><b>管理定位/相册/通知权限</b>：随时可以在系统设置里关闭，关闭后对应功能会受限但不影响其它功能</li>
  <li><b>联系我们</b>：对隐私问题有疑问，可以通过 App 内"意见反馈"联系我们</li>
</ul>

<h2>七、数据保留</h2>
<p>你注销账号后，我们会删除你的账号记录和你创建的内容（心愿、任务、时光胶囊、你上传的照片），
这些内容不再能被登录访问、也不再对任何人展示。</p>
<p>出于安全审计、故障排查和法律法规要求，下列信息会在注销后继续保留一段时间，
之后随例行清理一并删除：登录日志（设备型号、IP、时间）、崩溃与异常记录、
你提交过的意见反馈内容、匿名化的使用行为事件（不含你的心愿内容）。
这些记录不会用于识别你的身份，也不会用于任何商业用途。</p>

<h2>八、未成年人保护</h2>
<p>本 App 不主动收集未成年人的身份信息。如果你是未成年人，请在监护人指导下使用本 App。
监护人如发现未成年人在未经同意的情况下使用了本 App 并提供了个人信息，可通过"意见反馈"联系我们协助处理。</p>

<h2>九、政策的更新</h2>
<p>我们可能会不定期修订本政策，重大变更会在 App 内以公告形式提示你。
继续使用本 App 即代表你同意更新后的政策。</p>

<h2>十、联系我们</h2>
<p>对本政策或你的个人信息有任何问题，欢迎通过 App 内「我的 → 意见反馈」联系我们，
我们会尽快处理。</p>
`,
  );
}

/** POST /account-deletion —— 给静态托管上的注销页用（网页版删除链接，
 * 见 DELETION_PAGE_URL）。**只登记申请，不当场注销**：真正的注销由管理端
 * 「注销申请」页人工执行（走 POST /admin/users/:uid/delete，同一个
 * softDeleteUser）。Google Play 认可人工处理的申请渠道。
 *
 * 仍然校验密码：账号没绑邮箱手机号，管理员事后没有任何办法核实申请人是不是
 * 号主，所以身份核实必须在这里做完，不能只填个账号名就受理——否则等于给了
 * 任何人一个删别人账号的按钮。
 *
 * ⚠️ 页面文案说的是「申请已提交，X 个工作日内完成」，不是「已注销」。
 * 别改成后者：用户会以为数据删了，而账号其实还能登录，那是在删除权上撒谎。
 * 也别反过来把密码校验拆掉，见上一段。 */
export async function accountDeletionSubmit(req: Req): Promise<Res> {
  const b = req.body ?? {};
  const account = String(b.account ?? '').trim().toLowerCase();
  const password = String(b.password ?? '');
  if (!account || !password) return json(400, { error: 'missing_fields' });

  const db = getDb();
  const user = await db.getUserByAccount(account);
  // 已注销的账号 getUserByAccount 本来就查不到，走同一个错误分支——
  // 不告诉调用方「这个账号存在但密码错」还是「这个账号不存在」
  if (!user || !user.passwordHash || !verifyPassword(password, user.passwordHash)) {
    return json(401, { error: 'invalid_credentials' });
  }
  // 被封禁的账号照样允许提交：删除权不该因为封禁被剥夺
  try {
    await db.ensureCollection(COL.deletionRequests);
    // 同一个账号重复提交不再堆记录，管理端列表只需要看到一条待处理
    const { items } = await db.listDocs(COL.deletionRequests, {
      where: { uid: user._id },
      limit: 1,
      excludeTrue: ['handled'],
    });
    if (items.length === 0) {
      await db.upsertDoc(COL.deletionRequests, undefined, {
        uid: user._id,
        account: user.account,
        nickname: user.nickname ?? '',
        handled: false,
        createdAt: Date.now(),
      });
    }
  } catch (e) {
    // 登记失败必须让用户知道，不能回 received 让人以为已经排上队了
    return json(500, { error: 'internal_error', message: String((e as any)?.message ?? e) });
  }
  return json(200, { received: true });
}

export async function termsPage(): Promise<Res> {
  return page(
    '用户协议',
    `
<p>欢迎使用「人生清单」。本协议是你与 ${ENTITY} 之间关于使用本 App 服务的约定。
注册或使用本 App 即代表你已阅读并同意本协议和《隐私政策》。</p>

<h2>一、账号注册与安全</h2>
<ul>
  <li>你需要设置一个账号名和密码完成注册，账号名不得包含违法、侵权或不当内容</li>
  <li>你要对自己账号下的行为负责，请妥善保管密码，不要转借他人使用</li>
  <li>发现账号被盗用，请尽快通过"意见反馈"联系我们</li>
</ul>

<h2>二、服务内容</h2>
<p>本 App 提供心愿清单记录、任务管理、时光胶囊、成就系统、排行榜、社区热度统计等功能。
我们会持续迭代产品，部分功能可能调整、新增或下线，我们会尽量提前告知。</p>

<h2>三、使用规范</h2>
<p>使用本 App 时，你同意不会：</p>
<ul>
  <li>发布违法、色情、暴力、辱骂、侵犯他人权益的内容（心愿标题、昵称、时光胶囊等）</li>
  <li>利用本 App 从事任何违反法律法规的活动</li>
  <li>恶意攻击、干扰本 App 的正常运行（如爬虫、批量注册、破解等）</li>
  <li>冒充他人或虚构身份注册账号</li>
</ul>
<p>我们设有屏蔽词机制，违规内容可能被限制展示；情节严重的账号可能被封禁。</p>

<h2>四、内容与知识产权</h2>
<ul>
  <li>你在本 App 内创建的心愿、笔记、时光胶囊等内容归你所有，我们只是提供存储和展示服务</li>
  <li>本 App 的软件、界面设计、图标、文案等知识产权归 ${ENTITY} 所有，未经许可不得复制、反编译、二次分发</li>
  <li>你主动生成分享链接对外传播的内容，视为你同意该内容可被链接接收方查看</li>
</ul>

<h2>五、服务的中断与终止</h2>
<p>如遇不可抗力、系统维护、上游服务商（腾讯云开发等）故障等情况，本 App 可能出现服务中断，
我们会尽力尽快恢复。你也可以随时通过账号注销功能终止使用本服务。</p>

<h2>六、免责声明</h2>
<p>本 App 提供的心愿模板、里程碑建议、统计数据仅供参考，不构成任何专业建议。
因不可抗力、网络环境、设备兼容性等非我方过错导致的服务异常，我们不承担相应责任，
但会积极协助排查和修复。</p>

<h2>七、协议的变更</h2>
<p>我们可能会修订本协议，重大变更会在 App 内公告提示，继续使用即代表你同意变更后的内容。</p>

<h2>八、联系方式</h2>
<p>对本协议有任何疑问，欢迎通过 App 内「我的 → 意见反馈」联系我们。</p>
`,
  );
}
