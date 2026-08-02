set -u
B=http://127.0.0.1:8799
pass=0; fail=0
t() { # t 名称 期望片段 实际
  if echo "$3" | grep -q "$2"; then echo "  ✅ $1"; pass=$((pass+1));
  else echo "  ❌ $1 → $3"; fail=$((fail+1)); fi
}
echo "【鉴权】"
t "健康检查" '"ok":true' "$(curl -s $B/health)"
t "发验证码" 'ok\|code' "$(curl -s -XPOST $B/auth/send-code -H 'content-type: application/json' -d '{"email":"t@e.com"}')"
curl -s -XPOST $B/auth/send-code -H 'content-type: application/json' -d '{"email":"reg@e.com"}' > /dev/null
sleep 1
CODE=$(grep -o '验证码: [0-9]*' /tmp/be.log | tail -1 | grep -o '[0-9]*')
REG=$(curl -s -XPOST $B/auth/register -H 'content-type: application/json' -d "{\"email\":\"reg@e.com\",\"password\":\"pw123456\",\"code\":\"${CODE:-000000}\"}")
t "注册返回 token" '"token"' "$REG"
TOK=$(echo "$REG" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
t "登录" '"token"' "$(curl -s -XPOST $B/auth/login -H 'content-type: application/json' -d '{"email":"reg@e.com","password":"pw123456"}')"
t "错密码被拒" 'error\|401\|invalid' "$(curl -s -XPOST $B/auth/login -H 'content-type: application/json' -d '{"email":"reg@e.com","password":"wrong"}')"
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
t "推送心愿/任务/信" 'accepted' "$(curl -s -XPOST $B/sync/push -H "$H_AUTH" -H 'content-type: application/json' -d '{"wishes":[{"_id":"w1","title":"跑五公里","color":"A8B8F8","done":true,"doneAt":1730000000000,"location":"杭州","createdAt":1720000000000,"updatedAt":1730000000000}],"tasks":[{"_id":"t1","title":"晨跑","day":"2026-08-02","done":true,"createdAt":1,"updatedAt":2}],"letters":[{"_id":"l1","title":"给十年后","content":"hi","openAt":1900000000000,"createdAt":1,"updatedAt":2}]}')"
PULL=$(curl -s "$B/sync/pull?since=0" -H "$H_AUTH")
t "拉回心愿" '跑五公里' "$PULL"
t "拉回任务" '晨跑' "$PULL"
t "拉回信" '给十年后' "$PULL"
t "软删除生效" 'deleted' "$(curl -s -XPOST $B/sync/push -H "$H_AUTH" -H 'content-type: application/json' -d '{"tasks":[{"_id":"t1","title":"晨跑","day":"2026-08-02","done":true,"deleted":true,"createdAt":1,"updatedAt":9}]}'; curl -s "$B/sync/pull?since=0" -H "$H_AUTH")"
echo "【分享 / 上传】"
SH=$(curl -s -XPOST $B/share -H "$H_AUTH" -H 'content-type: application/json' -d '{"wishId":"w1","title":"跑五公里","quote":"做到了","color":"A8B8F8"}')
t "生成分享短码" '"path"\|"code"' "$SH"
SC=$(echo "$SH" | grep -o '"code":"[^"]*"' | cut -d'"' -f4)
t "短码可读取" '跑五公里' "$(curl -s $B/share/${SC:-x})"
t "换直传凭证" 'url\|downloadUrl' "$(curl -s -XPOST $B/upload -H "$H_AUTH" -H 'content-type: application/json' -d '{"mime":"image/jpeg"}')"
t "换新鲜图片链接" 'urls' "$(curl -s -XPOST $B/photo-urls -H "$H_AUTH" -H 'content-type: application/json' -d '{"urls":["https://x/a.jpg"]}')"
echo "【注销】"
t "注销账号" 'deleted\|true' "$(curl -s -XDELETE $B/auth/account -H "$H_AUTH")"
echo
echo "后端结果：$pass 通过 / $fail 失败"
