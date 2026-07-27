// 发验证码邮件：mock 模式 / 没配 SMTP 时打到控制台（不阻断注册流程）；配好 SMTP 后才真发信。
import { SMTP_FROM, SMTP_HOST, SMTP_PASS, SMTP_PORT, SMTP_USER } from './config';

let _transporter: any = null;
function transporter() {
  if (_transporter) return _transporter;
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const nodemailer = require('nodemailer');
  _transporter = nodemailer.createTransport({
    host: SMTP_HOST,
    port: SMTP_PORT,
    secure: SMTP_PORT === 465,
    auth: { user: SMTP_USER, pass: SMTP_PASS },
  });
  return _transporter;
}

export async function sendVerificationCode(email: string, code: string) {
  if (!SMTP_HOST || !SMTP_USER || !SMTP_PASS) {
    console.log(`[mail-skipped，未配置 SMTP] -> ${email} 验证码: ${code}（10 分钟内有效）`);
    return;
  }
  await transporter().sendMail({
    from: SMTP_FROM,
    to: email,
    subject: '【人生清单】邮箱验证码',
    text: `你的验证码是 ${code}，10 分钟内有效。如非本人操作请忽略本邮件。`,
  });
}
