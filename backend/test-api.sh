set -u
# 默认直接打线上（已经没有 mock 后端了）。本地起 npm run dev 时：
#   API_BASE=http://127.0.0.1:8787 sh test-api.sh
B=${API_BASE:-https://renshengqingdan-d8feva5q55d12bab-1258070735.ap-shanghai.app.tcloudbase.com/api}
# 账号名带时间戳，免得重复跑撞上「已注册」
U=t$(date +%s)
# 记录 id 也要带时间戳：id 撞上别的用户时，服务端会按归属拒改（这是对的），
# 写死 w1/t1/l1 的话第二次跑就会静默失败
pass=0; fail=0
t() { # t 名称 期望片段 实际
  if echo "$3" | grep -q "$2"; then echo "  ✅ $1"; pass=$((pass+1));
  else echo "  ❌ $1 → $3"; fail=$((fail+1)); fi
}
echo "【鉴权】"
t "健康检查" '"ok":true' "$(curl -s $B/health)"
REG=$(curl -s -XPOST $B/auth/register -H 'content-type: application/json' -d '{"account":"'"$U"'","password":"pw123456"}')
t "注册返回 token" '"token"' "$REG"
t "非法账号被拒" 'invalid_account' "$(curl -s -XPOST $B/auth/register -H 'content-type: application/json' -d '{"account":"a b","password":"pw123456"}')"
t "重复账号被拒" 'account_exists' "$(curl -s -XPOST $B/auth/register -H 'content-type: application/json' -d '{"account":"'"$U"'","password":"pw123456"}')"
TOK=$(echo "$REG" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
t "登录" '"token"' "$(curl -s -XPOST $B/auth/login -H 'content-type: application/json' -d '{"account":"'"$U"'","password":"pw123456"}')"
t "错密码被拒" 'error\|401\|invalid' "$(curl -s -XPOST $B/auth/login -H 'content-type: application/json' -d '{"account":"'"$U"'","password":"wrong"}')"
t "无 token 访问 /me 被拒" 'error\|401\|unauth' "$(curl -s $B/me)"
A="-H authorization:Bearer${TOK:+ Bearer $TOK}"
H_AUTH="authorization: Bearer $TOK"
echo "【资料】"
t "GET /me" '"profile"' "$(curl -s $B/me -H "$H_AUTH")"
t "改昵称" '松之改' "$(curl -s -XPATCH $B/me -H "$H_AUTH" -H 'content-type: application/json' -d '{"nickname":"松之改"}')"
t "存头像 avatarUrl" 'avatar.png' "$(curl -s -XPATCH $B/me -H "$H_AUTH" -H 'content-type: application/json' -d '{"avatarUrl":"https://x/avatar.png"}')"
t "存成就 achievements" '初试身手' "$(curl -s -XPATCH $B/me -H "$H_AUTH" -H 'content-type: application/json' -d '{"achievements":{"初试身手":1730000000000}}')"
t "成就能读回" '初试身手' "$(curl -s $B/me -H "$H_AUTH")"
echo "【同步】"
PUSH1='{"wishes":[{"_id":"w-'"$U"'","title":"跑五公里","color":"A8B8F8","done":true,"doneAt":1730000000000,"location":"杭州","createdAt":1720000000000,"updatedAt":1730000000000}],"tasks":[{"_id":"t-'"$U"'","title":"晨跑","day":"2026-08-02","done":true,"createdAt":1,"updatedAt":2}],"letters":[{"_id":"l-'"$U"'","title":"给十年后","content":"hi","openAt":1900000000000,"createdAt":1,"updatedAt":2}]}'
t "推送心愿/任务/信" 'accepted' "$(curl -s -XPOST $B/sync/push -H "$H_AUTH" -H 'content-type: application/json' -d "$PUSH1")"
PULL=$(curl -s "$B/sync/pull?since=0" -H "$H_AUTH")
t "拉回心愿" '跑五公里' "$PULL"
t "拉回任务" '晨跑' "$PULL"
t "拉回信" '给十年后' "$PULL"
DEL1='{"tasks":[{"_id":"t-'"$U"'","title":"晨跑","day":"2026-08-02","done":true,"deleted":true,"createdAt":1,"updatedAt":9}]}'
t "软删除生效" 'deleted' "$(curl -s -XPOST $B/sync/push -H "$H_AUTH" -H 'content-type: application/json' -d "$DEL1"; curl -s "$B/sync/pull?since=0" -H "$H_AUTH")"
echo "【分享 / 上传】"
SHB='{"wishId":"w-'"$U"'","title":"跑五公里","quote":"做到了","color":"A8B8F8"}'
SH=$(curl -s -XPOST $B/share -H "$H_AUTH" -H 'content-type: application/json' -d "$SHB")
t "生成分享短码" '"path"\|"code"' "$SH"
SC=$(echo "$SH" | grep -o '"code":"[^"]*"' | cut -d'"' -f4)
t "短码可读取" '跑五公里' "$(curl -s $B/share/${SC:-x})"
t "换直传凭证" 'url\|downloadUrl' "$(curl -s -XPOST $B/upload -H "$H_AUTH" -H 'content-type: application/json' -d '{"mime":"image/jpeg"}')"
t "换新鲜图片链接" 'urls' "$(curl -s -XPOST $B/photo-urls -H "$H_AUTH" -H 'content-type: application/json' -d '{"urls":["https://x/a.jpg"]}')"
echo "【注销】"
t "注销账号" 'deleted\|true' "$(curl -s -XDELETE $B/auth/account -H "$H_AUTH")"
t "注销后老密码登不进去" 'invalid_credentials' "$(curl -s -XPOST $B/auth/login -H 'content-type: application/json' -d '{"account":"'"$U"'","password":"pw123456"}')"
# 已注销的记录不能再占着账号名，否则这个名字就废了
t "注销后同名可重新注册" '"token"' "$(curl -s -XPOST $B/auth/register -H 'content-type: application/json' -d '{"account":"'"$U"'","password":"newpw123"}')"
t "重注册后用新密码能登录" '"token"' "$(curl -s -XPOST $B/auth/login -H 'content-type: application/json' -d '{"account":"'"$U"'","password":"newpw123"}')"
echo
echo "后端结果：$pass 通过 / $fail 失败"
