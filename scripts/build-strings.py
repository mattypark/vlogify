#!/usr/bin/env python3
"""Builds ios/Vlogify/Resources/Localizable.xcstrings and InfoPlist.xcstrings.

English is the source language and the key. Korean is hand-written. Japanese,
Traditional Chinese, Vietnamese and Russian are drafted and marked "needs_review"
in the catalog so Xcode shows them as such -- a native pass before launch is a
task in docs/STAGES.md, not something this file pretends is done.

Re-run after adding strings: `python3 scripts/build-strings.py`. Untranslated keys
are listed at the end so nothing ships silently English.
"""
import json, re, subprocess, sys, os

os.chdir(os.path.join(os.path.dirname(__file__), ".."))

# key: (ko, ja, zh-Hant, vi, ru)
T = {
 "%@ blocked.": ("%@님을 차단했어요.", "%@ をブロックしました。", "已封鎖 %@。", "đã chặn %@.", "%@ заблокирован."),
 "%@ missed this hour": ("%@님은 이 시간을 놓쳤어요", "%@ はこの時間を逃しました", "%@ 錯過了這個小時", "%@ đã bỏ lỡ giờ này", "%@ пропустил этот час"),
 "%@'s clip": ("%@님의 클립", "%@ のクリップ", "%@ 的片段", "clip của %@", "клип %@"),
 "%lld clips today": ("오늘 클립 %lld개", "今日のクリップ %lld 本", "今天 %lld 段片段", "%lld clip hôm nay", "клипов сегодня: %lld"),
 "%lld of %lld hours posted": ("%lld/%lld 시간 올림", "%lld / %lld 時間を投稿", "已發布 %lld / %lld 小時", "đã đăng %lld / %lld giờ", "опубликовано часов: %lld из %lld"),
 "%lld of %lld in": ("%lld/%lld명 참여 중", "%lld / %lld 人が参加中", "%lld / %lld 人已加入", "%lld / %lld người đã vào", "в комнате %lld из %lld"),
 "(new group)": ("(새 그룹)", "（新しいグループ）", "（新群組）", "(nhóm mới)", "(новая группа)"),
 "(with a code)": ("(코드로)", "（コードで）", "（用代碼）", "(bằng mã)", "(по коду)"),
 "24hrs, up to 40 friends": ("24시간, 최대 40명", "24時間、最大40人", "24 小時，最多 40 位朋友", "24 giờ, tối đa 40 bạn", "24 часа, до 40 друзей"),
 "Continue with Google": ("Google로 계속하기", "Googleで続ける", "使用 Google 繼續", "Tiếp tục với Google", "Продолжить с Google"),
 "Continue with email": ("이메일로 계속하기", "メールで続ける", "使用電子郵件繼續", "Tiếp tục với email", "Продолжить по почте"),
 "about": ("정보", "情報", "關於", "giới thiệu", "о приложении"),
 "account": ("계정", "アカウント", "帳號", "tài khoản", "аккаунт"),
 "add a 2s clip every hour.": ("매시간 2초 클립을 올려요.", "1時間ごとに2秒のクリップを追加。", "每小時新增一段 2 秒片段。", "thêm một clip 2 giây mỗi giờ.", "добавляй 2-секундный клип каждый час."),
 "add clip": ("클립 추가", "クリップを追加", "新增片段", "thêm clip", "добавить клип"),
 "allow photos access in settings to save.": ("저장하려면 설정에서 사진 접근을 허용해 주세요.", "保存するには設定で写真へのアクセスを許可してください。", "請在設定中允許存取照片以儲存。", "cho phép truy cập ảnh trong cài đặt để lưu.", "разрешите доступ к фото в настройках, чтобы сохранить."),
 "also block %@": ("%@님도 차단하기", "%@ もブロック", "同時封鎖 %@", "chặn luôn %@", "также заблокировать %@"),
 "anyone with this code can join %@.": ("이 코드가 있으면 누구나 %@에 참여할 수 있어요.", "このコードを知っている人は %@ に参加できます。", "任何擁有此代碼的人都可以加入 %@。", "ai có mã này đều có thể vào %@.", "любой с этим кодом может войти в %@."),
 "anything else (optional)": ("추가 설명 (선택)", "その他（任意）", "其他說明（選填）", "thêm gì nữa không (tuỳ chọn)", "что-нибудь ещё (необязательно)"),
 "back to today": ("오늘로 돌아가기", "今日に戻る", "回到今天", "về hôm nay", "к сегодня"),
 "block %@": ("%@님 차단", "%@ をブロック", "封鎖 %@", "chặn %@", "заблокировать %@"),
 "blocked people": ("차단한 사람", "ブロックした人", "已封鎖的人", "người đã chặn", "заблокированные"),
 "camera": ("카메라", "カメラ", "相機", "camera", "камера"),
 "cancel": ("취소", "キャンセル", "取消", "huỷ", "отмена"),
 "capture 2s clips to share with close friends.": ("친한 친구들과 나눌 2초 클립을 찍어요.", "親しい友だちと共有する2秒クリップを撮影します。", "拍攝 2 秒片段與好友分享。", "quay clip 2 giây để chia sẻ với bạn thân.", "снимать 2-секундные клипы для близких друзей."),
 "check your email": ("이메일을 확인하세요", "メールを確認してください", "請查看你的電子郵件", "kiểm tra email của bạn", "проверьте почту"),
 "clips are only visible to the room you post them in.": ("클립은 올린 방에서만 볼 수 있어요.", "クリップは投稿したルームでだけ見られます。", "片段只有你發布的房間看得到。", "clip chỉ hiển thị trong phòng bạn đăng.", "клипы видны только в той комнате, куда ты их выложил."),
 "clips on this phone": ("이 기기의 클립", "この端末のクリップ", "此手機上的片段", "clip trên máy này", "клипы на этом телефоне"),
 "close": ("닫기", "閉じる", "關閉", "đóng", "закрыть"),
 "continue →": ("계속 →", "続ける →", "繼續 →", "tiếp tục →", "далее →"),
 "copied": ("복사됨", "コピーしました", "已複製", "đã sao chép", "скопировано"),
 "copy code": ("코드 복사", "コードをコピー", "複製代碼", "sao chép mã", "скопировать код"),
 "couldn't create the room. try again.": ("방을 만들지 못했어요. 다시 시도해 주세요.", "ルームを作成できませんでした。もう一度お試しください。", "無法建立房間。請再試一次。", "không tạo được phòng. thử lại nhé.", "не удалось создать комнату. попробуй ещё раз."),
 "couldn't delete right now. try again.": ("지금은 삭제할 수 없어요. 다시 시도해 주세요.", "今は削除できません。もう一度お試しください。", "目前無法刪除。請再試一次。", "chưa xoá được. thử lại nhé.", "не удалось удалить. попробуй ещё раз."),
 "couldn't join. try again.": ("참여하지 못했어요. 다시 시도해 주세요.", "参加できませんでした。もう一度お試しください。", "無法加入。請再試一次。", "không vào được. thử lại nhé.", "не удалось войти. попробуй ещё раз."),
 "couldn't load your rooms.": ("방을 불러오지 못했어요.", "ルームを読み込めませんでした。", "無法載入你的房間。", "không tải được phòng của bạn.", "не удалось загрузить комнаты."),
 "couldn't save that clip. try again.": ("클립을 저장하지 못했어요. 다시 시도해 주세요.", "クリップを保存できませんでした。もう一度お試しください。", "無法儲存該片段。請再試一次。", "không lưu được clip đó. thử lại nhé.", "не удалось сохранить клип. попробуй ещё раз."),
 "couldn't save that. try again.": ("저장하지 못했어요. 다시 시도해 주세요.", "保存できませんでした。もう一度お試しください。", "無法儲存。請再試一次。", "không lưu được. thử lại nhé.", "не удалось сохранить. попробуй ещё раз."),
 "couldn't save to photos.": ("사진에 저장하지 못했어요.", "写真に保存できませんでした。", "無法儲存到照片。", "không lưu được vào ảnh.", "не удалось сохранить в фото."),
 "couldn't sign in. try again.": ("로그인하지 못했어요. 다시 시도해 주세요.", "サインインできませんでした。もう一度お試しください。", "無法登入。請再試一次。", "không đăng nhập được. thử lại nhé.", "не удалось войти. попробуй ещё раз."),
 "couldn't stitch the day. try again.": ("하루를 이어 붙이지 못했어요. 다시 시도해 주세요.", "1日をつなげられませんでした。もう一度お試しください。", "無法拼接這一天。請再試一次。", "không ghép được ngày hôm nay. thử lại nhé.", "не удалось собрать день. попробуй ещё раз."),
 "create": ("만들기", "作成", "建立", "tạo", "создать"),
 "create a room": ("방 만들기", "ルームを作る", "建立房間", "tạo phòng", "создать комнату"),
 "create log": ("로그 만들기", "ログを作る", "建立日誌", "tạo log", "создать лог"),
 "day resets at 4AM.\nfind past days in history.": ("하루는 새벽 4시에 리셋돼요.\n지난 날은 히스토리에서 볼 수 있어요.", "1日は午前4時にリセット。\n過去の日は履歴で見られます。", "一天在凌晨 4 點重置。\n過去的日子在歷史中。", "ngày reset lúc 4 giờ sáng.\nxem lại các ngày cũ trong lịch sử.", "день сбрасывается в 4 утра.\nпрошлые дни — в истории."),
 "delete": ("삭제", "削除", "刪除", "xoá", "удалить"),
 "delete account": ("계정 삭제", "アカウントを削除", "刪除帳號", "xoá tài khoản", "удалить аккаунт"),
 "delete everything": ("모두 삭제", "すべて削除", "全部刪除", "xoá tất cả", "удалить всё"),
 "delete my clip": ("내 클립 삭제", "自分のクリップを削除", "刪除我的片段", "xoá clip của tôi", "удалить мой клип"),
 "delete this vlog": ("이 브이로그 삭제", "このVlogを削除", "刪除此 vlog", "xoá vlog này", "удалить этот влог"),
 "delete this vlog?": ("이 브이로그를 삭제할까요?", "このVlogを削除しますか？", "要刪除此 vlog 嗎？", "xoá vlog này?", "удалить этот влог?"),
 "delete your account?": ("계정을 삭제할까요?", "アカウントを削除しますか？", "要刪除你的帳號嗎？", "xoá tài khoản của bạn?", "удалить аккаунт?"),
 "deleting removes your account, your clips, and the rooms you own. it cannot be undone.": ("삭제하면 계정, 클립, 내가 만든 방이 모두 사라져요. 되돌릴 수 없어요.", "削除するとアカウント、クリップ、作成したルームが消えます。元に戻せません。", "刪除會移除你的帳號、片段和你建立的房間，且無法復原。", "xoá sẽ gỡ tài khoản, clip và các phòng bạn sở hữu. không thể hoàn tác.", "удаление сотрёт аккаунт, клипы и твои комнаты. это необратимо."),
 "done": ("완료", "完了", "完成", "xong", "готово"),
 "done →": ("완료 →", "完了 →", "完成 →", "xong →", "готово →"),
 "flash": ("플래시", "フラッシュ", "閃光燈", "đèn flash", "вспышка"),
 "flip camera": ("카메라 전환", "カメラを切り替え", "切換相機", "đổi camera", "переключить камеру"),
 "harassment or bullying": ("괴롭힘", "嫌がらせ・いじめ", "騷擾或霸凌", "quấy rối hoặc bắt nạt", "травля или домогательства"),
 "help & support": ("도움말 및 지원", "ヘルプとサポート", "說明與支援", "trợ giúp & hỗ trợ", "помощь и поддержка"),
 "history": ("히스토리", "履歴", "歷史", "lịch sử", "история"),
 "hourly pings": ("매시간 알림", "毎時の通知", "每小時提醒", "nhắc mỗi giờ", "ежечасные напоминания"),
 "invite": ("초대", "招待", "邀請", "mời", "пригласить"),
 "invite code %@": ("초대 코드 %@", "招待コード %@", "邀請代碼 %@", "mã mời %@", "код приглашения %@"),
 "invite friends": ("친구 초대", "友だちを招待", "邀請朋友", "mời bạn bè", "пригласить друзей"),
 "it's %@. add your 2s clip.": ("%@이에요. 2초 클립을 올려요.", "%@ です。2秒クリップを追加。", "現在 %@，新增你的 2 秒片段。", "đã %@. thêm clip 2 giây của bạn.", "сейчас %@. добавь свой 2-секундный клип."),
 "it's %@. add your clip.": ("%@이에요. 클립을 올려요.", "%@ です。クリップを追加。", "現在 %@，新增你的片段。", "đã %@. thêm clip của bạn.", "сейчас %@. добавь свой клип."),
 "join": ("참여", "参加", "加入", "vào", "войти"),
 "join log": ("로그 참여", "ログに参加", "加入日誌", "vào log", "войти в лог"),
 "join my vlogify room: %@": ("내 vlogify 방에 들어와: %@", "vlogifyのルームに参加して: %@", "加入我的 vlogify 房間：%@", "vào phòng vlogify của mình: %@", "заходи в мою комнату vlogify: %@"),
 "join with code": ("코드로 참여", "コードで参加", "用代碼加入", "vào bằng mã", "войти по коду"),
 "just you": ("나 혼자", "自分だけ", "只有你", "chỉ mình bạn", "только ты"),
 "language": ("언어", "言語", "語言", "ngôn ngữ", "язык"),
 "leave": ("나가기", "退出", "離開", "rời", "выйти"),
 "leave room": ("방 나가기", "ルームを退出", "離開房間", "rời phòng", "выйти из комнаты"),
 "leave this room?": ("이 방을 나갈까요?", "このルームを退出しますか？", "要離開此房間嗎？", "rời phòng này?", "выйти из комнаты?"),
 "let's go": ("시작하기", "はじめる", "開始吧", "bắt đầu thôi", "поехали"),
 "log": ("로그", "ログ", "日誌", "nhật ký", "лог"),
 "logs": ("로그", "ログ", "日誌", "nhật ký", "логи"),
 "make or join a room first.": ("먼저 방을 만들거나 참여하세요.", "まずルームを作るか参加してください。", "請先建立或加入房間。", "tạo hoặc vào một phòng trước nhé.", "сначала создай комнату или войди в неё."),
 "new": ("새로 만들기", "新規", "新增", "mới", "новое"),
 "new moment every hour,\nvlog it with your friends.": ("매시간 새로운 순간,\n친구들과 브이로그해요.", "1時間ごとに新しい瞬間を、\n友だちとVlogに。", "每小時一個新時刻，\n和朋友一起 vlog。", "mỗi giờ một khoảnh khắc mới,\nvlog cùng bạn bè.", "новый момент каждый час —\nвлог вместе с друзьями."),
 "new room": ("새 방", "新しいルーム", "新房間", "phòng mới", "новая комната"),
 "next ping in %@": ("다음 알림까지 %@", "次の通知まで %@", "%@ 後下次提醒", "nhắc tiếp sau %@", "следующее напоминание через %@"),
 "no past days yet. tomorrow, today will be here.": ("아직 지난 날이 없어요. 내일이면 오늘이 여기 있을 거예요.", "まだ過去の日はありません。明日になれば今日がここに。", "還沒有過去的日子。明天，今天就會在這裡。", "chưa có ngày nào cũ. ngày mai, hôm nay sẽ ở đây.", "прошлых дней пока нет. завтра здесь будет сегодня."),
 "no pings yet. logs with friends ping every hour.": ("아직 알림이 없어요. 친구와 함께하는 로그는 매시간 알려줘요.", "まだ通知はありません。友だちとのログは毎時通知します。", "還沒有提醒。與朋友的日誌每小時提醒一次。", "chưa có nhắc nào. log cùng bạn bè nhắc mỗi giờ.", "напоминаний пока нет. логи с друзьями напоминают каждый час."),
 "no room with that code.": ("그 코드의 방이 없어요.", "そのコードのルームはありません。", "沒有該代碼的房間。", "không có phòng nào với mã đó.", "комнаты с таким кодом нет."),
 "nobody blocked.": ("차단한 사람이 없어요.", "ブロックした人はいません。", "沒有封鎖任何人。", "chưa chặn ai.", "никто не заблокирован."),
 "nothing this hour": ("이 시간엔 없어요", "この時間はなし", "這個小時沒有內容", "giờ này chưa có gì", "в этот час ничего"),
 "notifications": ("알림", "通知", "通知", "thông báo", "уведомления"),
 "now": ("지금", "今", "現在", "bây giờ", "сейчас"),
 "nudity": ("노출", "ヌード", "裸露", "khoả thân", "нагота"),
 "off": ("끔", "オフ", "關", "tắt", "выкл"),
 "on": ("켬", "オン", "開", "bật", "вкл"),
 "one nudge an hour, same moment as your friends.": ("한 시간에 한 번, 친구들과 같은 순간에 알려줘요.", "1時間に1回、友だちと同じ瞬間にお知らせ。", "每小時提醒一次，和朋友同一時刻。", "một lần nhắc mỗi giờ, cùng lúc với bạn bè.", "одно напоминание в час, в тот же момент, что и друзьям."),
 "open settings": ("설정 열기", "設定を開く", "開啟設定", "mở cài đặt", "открыть настройки"),
 "pings": ("알림", "通知", "提醒", "nhắc", "напоминания"),
 "play the day": ("하루 재생", "1日を再生", "播放這一天", "phát cả ngày", "смотреть день"),
 "post to": ("올릴 방", "投稿先", "發布到", "đăng vào", "куда выложить"),
 "posted %@.": ("%@ 올렸어요.", "%@ を投稿しました。", "已發布 %@。", "đã đăng %@.", "выложено: %@."),
 "posted %@. next ping in %@": ("%@ 올렸어요. 다음 알림까지 %@", "%@ を投稿。次の通知まで %@", "已發布 %@。%@ 後下次提醒", "đã đăng %@. nhắc tiếp sau %@", "выложено: %@. следующее через %@"),
 "pretending to be someone": ("사칭", "なりすまし", "冒充他人", "giả mạo người khác", "выдаёт себя за другого"),
 "privacy policy": ("개인정보 처리방침", "プライバシーポリシー", "隱私權政策", "chính sách quyền riêng tư", "политика конфиденциальности"),
 "profile": ("프로필", "プロフィール", "個人檔案", "hồ sơ", "профиль"),
 "reason": ("이유", "理由", "原因", "lý do", "причина"),
 "record": ("녹화", "録画", "錄製", "quay", "записать"),
 "record sound while capturing clips.": ("클립을 찍을 때 소리도 녹음해요.", "クリップ撮影中に音声を録音します。", "拍攝片段時錄製聲音。", "ghi âm khi quay clip.", "записывать звук вместе с клипом."),
 "recording": ("녹화 중", "録画中", "錄製中", "đang quay", "запись"),
 "remove from room": ("방에서 내보내기", "ルームから削除", "從房間移除", "mời ra khỏi phòng", "удалить из комнаты"),
 "report": ("신고", "報告", "檢舉", "báo cáo", "пожаловаться"),
 "right now": ("지금 이 순간", "今この瞬間", "此刻", "ngay bây giờ", "прямо сейчас"),
 "room name (optional)": ("방 이름 (선택)", "ルーム名（任意）", "房間名稱（選填）", "tên phòng (tuỳ chọn)", "название комнаты (необязательно)"),
 "room size": ("방 인원", "ルームの人数", "房間人數", "số người", "размер комнаты"),
 "room type": ("방 종류", "ルームの種類", "房間類型", "loại phòng", "тип комнаты"),
 "rotate to capture": ("가로로 돌려서 찍어요", "横向きにして撮影", "旋轉以拍攝", "xoay ngang để quay", "поверни, чтобы снять"),
 "save to photos": ("사진에 저장", "写真に保存", "儲存到照片", "lưu vào ảnh", "сохранить в фото"),
 "saved to photos. post it anywhere.": ("사진에 저장했어요. 어디든 올려보세요.", "写真に保存しました。どこにでも投稿できます。", "已儲存到照片。隨處發布吧。", "đã lưu vào ảnh. đăng ở đâu cũng được.", "сохранено в фото. выкладывай куда угодно."),
 "see everyone's day\ncome together.": ("모두의 하루가\n하나로 모여요.", "みんなの1日が\nひとつになる。", "看見大家的一天\n合而為一。", "xem ngày của mọi người\nghép lại với nhau.", "смотри, как день каждого\nскладывается в один."),
 "send": ("보내기", "送信", "送出", "gửi", "отправить"),
 "send code": ("코드 보내기", "コードを送信", "傳送代碼", "gửi mã", "отправить код"),
 "settings": ("설정", "設定", "設定", "cài đặt", "настройки"),
 "share": ("공유", "共有", "分享", "chia sẻ", "поделиться"),
 "sign in": ("로그인", "サインイン", "登入", "đăng nhập", "войти"),
 "sign out": ("로그아웃", "サインアウト", "登出", "đăng xuất", "выйти из аккаунта"),
 "sign out?": ("로그아웃할까요?", "サインアウトしますか？", "要登出嗎？", "đăng xuất?", "выйти из аккаунта?"),
 "solo logs don't have limits.": ("혼자 하는 로그엔 제한이 없어요.", "ひとりログに制限はありません。", "個人日誌沒有限制。", "log một mình không có giới hạn.", "у сольных логов нет ограничений."),
 "something else": ("기타", "その他", "其他", "khác", "другое"),
 "something went wrong. try again in a moment.": ("문제가 생겼어요. 잠시 후 다시 시도해 주세요.", "問題が発生しました。しばらくしてからお試しください。", "發生錯誤。請稍後再試。", "có lỗi xảy ra. thử lại sau nhé.", "что-то пошло не так. попробуй чуть позже."),
 "spam": ("스팸", "スパム", "垃圾內容", "spam", "спам"),
 "stack": ("스택", "スタック", "堆疊", "stack", "стек"),
 "start a zip": ("zip 시작", "zipを始める", "開始 zip", "bắt đầu zip", "начать zip"),
 "stitching %lld hours…": ("%lld시간을 이어 붙이는 중…", "%lld 時間をつなげています…", "正在拼接 %lld 小時…", "đang ghép %lld giờ…", "собираю %lld ч…"),
 "tap": ("눌러서", "タップ", "點", "nhấn", "нажми"),
 "terms": ("이용약관", "利用規約", "條款", "điều khoản", "условия"),
 "thanks. we'll look at it.": ("고마워요. 확인해 볼게요.", "ありがとう。確認します。", "謝謝，我們會查看。", "cảm ơn. tụi mình sẽ xem.", "спасибо. мы посмотрим."),
 "that code didn't match. check the email and try again.": ("코드가 맞지 않아요. 이메일을 확인하고 다시 시도해 주세요.", "コードが一致しません。メールを確認してもう一度お試しください。", "代碼不符。請檢查電子郵件後再試。", "mã không khớp. kiểm tra email rồi thử lại.", "код не подошёл. проверь почту и попробуй ещё раз."),
 "that doesn't look like a code. check for a typo.": ("코드 형식이 아닌 것 같아요. 오타를 확인해 주세요.", "コードの形式ではないようです。入力ミスを確認してください。", "這看起來不像代碼。請檢查是否打錯。", "trông không giống mã. kiểm tra lỗi gõ nhé.", "не похоже на код. проверь опечатки."),
 "that room is full.": ("그 방은 꽉 찼어요.", "そのルームは満員です。", "該房間已滿。", "phòng đó đã đầy.", "комната заполнена."),
 "this is the name on your tiles.": ("타일에 표시될 이름이에요.", "タイルに表示される名前です。", "這是顯示在你方塊上的名字。", "đây là tên hiện trên ô của bạn.", "это имя будет на твоих плитках."),
 "to start": ("시작해요", "して開始", "開始", "để bắt đầu", "чтобы начать"),
 "today": ("오늘", "今日", "今天", "hôm nay", "сегодня"),
 "unblock": ("차단 해제", "ブロック解除", "解除封鎖", "bỏ chặn", "разблокировать"),
 "untitled log": ("이름 없는 로그", "無題のログ", "未命名日誌", "log chưa đặt tên", "лог без названия"),
 "use a different email": ("다른 이메일 사용", "別のメールを使う", "使用其他電子郵件", "dùng email khác", "другая почта"),
 "version": ("버전", "バージョン", "版本", "phiên bản", "версия"),
 "violence": ("폭력", "暴力", "暴力", "bạo lực", "насилие"),
 "vlog": ("브이로그", "Vlog", "vlog", "vlog", "влог"),
 "vlogify needs the camera and microphone to record a clip.": ("클립을 찍으려면 카메라와 마이크가 필요해요.", "クリップを撮影するにはカメラとマイクが必要です。", "vlogify 需要相機和麥克風才能錄製片段。", "vlogify cần camera và micro để quay clip.", "vlogify нужны камера и микрофон, чтобы записать клип."),
 "we need a few things first…": ("먼저 몇 가지 권한이 필요해요…", "まずいくつか必要なものがあります…", "我們先需要幾樣東西…", "cần vài thứ trước đã…", "сначала нужно кое-что…"),
 "we sent a 6-digit code to %@.": ("%@로 6자리 코드를 보냈어요.", "%@ に6桁のコードを送りました。", "已傳送 6 位數代碼到 %@。", "đã gửi mã 6 số đến %@.", "мы отправили 6-значный код на %@."),
 "what do friends call you?": ("친구들은 뭐라고 불러요?", "友だちはなんて呼ぶ？", "朋友怎麼稱呼你？", "bạn bè gọi bạn là gì?", "как тебя зовут друзья?"),
 "what's wrong with this clip?": ("이 클립에 어떤 문제가 있나요?", "このクリップの問題は？", "這段片段有什麼問題？", "clip này có vấn đề gì?", "что не так с этим клипом?"),
 "you": ("나", "自分", "你", "bạn", "ты"),
 "you + %lld friends": ("나 + 친구 %lld명", "自分 + 友だち %lld 人", "你 + %lld 位朋友", "bạn + %lld bạn bè", "ты + друзей: %lld"),
 "you + up to 19 friends": ("나 + 친구 최대 19명", "自分 + 友だち最大19人", "你 + 最多 19 位朋友", "bạn + tối đa 19 bạn bè", "ты + до 19 друзей"),
 "you already posted %@. next hour!": ("%@에 이미 올렸어요. 다음 시간에!", "%@ はもう投稿済み。次の時間に！", "你已發布 %@。下個小時見！", "bạn đã đăng %@ rồi. giờ sau nhé!", "ты уже выложил %@. в следующий час!"),
 "you already posted this hour.": ("이 시간엔 이미 올렸어요.", "この時間はもう投稿済みです。", "你這個小時已經發布過了。", "bạn đã đăng giờ này rồi.", "в этот час ты уже выложил."),
 "you and friends": ("나와 친구들", "自分と友だち", "你和朋友", "bạn và bạn bè", "ты и друзья"),
 "you'll need a new code to come back.": ("다시 들어오려면 새 코드가 필요해요.", "戻るには新しいコードが必要です。", "要回來需要新的代碼。", "muốn quay lại cần mã mới.", "чтобы вернуться, понадобится новый код."),
 "your clips in it go too.": ("그 안의 내 클립도 같이 사라져요.", "その中のクリップも消えます。", "裡面你的片段也會一併刪除。", "clip của bạn trong đó cũng mất.", "твои клипы в нём тоже удалятся."),
 "your clips, your rooms, and your sign-in are removed from vlogify's servers. friends keep their own clips.": ("내 클립, 방, 로그인 정보가 vlogify 서버에서 삭제돼요. 친구들의 클립은 그대로예요.", "あなたのクリップ、ルーム、サインインがvlogifyのサーバーから削除されます。友だちのクリップはそのままです。", "你的片段、房間和登入資訊會從 vlogify 伺服器移除。朋友保留他們自己的片段。", "clip, phòng và đăng nhập của bạn sẽ bị gỡ khỏi máy chủ vlogify. bạn bè vẫn giữ clip của họ.", "твои клипы, комнаты и вход будут удалены с серверов vlogify. клипы друзей останутся у них."),
 "your day, side by side.": ("너의 하루, 나란히.", "みんなの1日を、並べて。", "你的一天，並排呈現。", "ngày của bạn, kề bên nhau.", "твой день — бок о бок."),
 "your email": ("이메일", "メールアドレス", "你的電子郵件", "email của bạn", "твоя почта"),
 "your name": ("이름", "名前", "你的名字", "tên của bạn", "твоё имя"),
 "your room": ("내 방", "自分のルーム", "你的房間", "phòng của bạn", "твоя комната"),
 "zip": ("zip", "zip", "zip", "zip", "zip"),
 "invite code": ("초대 코드", "招待コード", "邀請代碼", "mã mời", "код приглашения"),
 "continue": ("계속", "続ける", "繼續", "tiếp tục", "далее"),
 "horizontal": ("가로", "横", "橫向", "ngang", "горизонтально"),
 "vertical": ("세로", "縦", "直向", "dọc", "вертикально"),
 "recording": ("촬영 방향", "撮影の向き", "錄製方向", "hướng quay", "ориентация съёмки"),
 "horizontal. tap for vertical": ("가로. 눌러서 세로로", "横。タップで縦に", "橫向。點按改為直向", "ngang. nhấn để chuyển dọc", "горизонтально. нажми для вертикали"),
 "vertical. tap for horizontal": ("세로. 눌러서 가로로", "縦。タップで横に", "直向。點按改為橫向", "dọc. nhấn để chuyển ngang", "вертикально. нажми для горизонтали"),
 "skip for now": ("일단 건너뛰기", "今はスキップ", "暫時略過", "bỏ qua tạm thời", "пока пропустить"),
 "add a note": ("메모 추가", "メモを追加", "新增筆記", "thêm ghi chú", "добавить заметку"),
 "write something…": ("무언가 적어보세요…", "何か書いてみて…", "寫點什麼…", "viết gì đó…", "напиши что-нибудь…"),
 "tap to write about today…": ("오늘에 대해 적어보세요…", "今日のことを書いてみて…", "點按寫下今天…", "nhấn để viết về hôm nay…", "нажми и напиши о сегодняшнем дне…"),
 "write something about this room…": ("이 방에 대해 적어보세요…", "このルームについて書いてみて…", "寫點關於這個房間的事…", "viết gì đó về phòng này…", "напиши что-нибудь об этой комнате…"),
 "make text": ("일반 글로", "テキストにする", "改為文字", "thành văn bản", "сделать текстом"),
 "make heading": ("제목으로", "見出しにする", "改為標題", "thành tiêu đề", "сделать заголовком"),
 "make to-do": ("할 일로", "ToDoにする", "改為待辦", "thành việc cần làm", "сделать задачей"),
 "to do": ("할 일", "未完了", "待辦", "cần làm", "нужно сделать"),
 "previous day": ("이전 날", "前の日", "前一天", "ngày trước", "предыдущий день"),
 "next day": ("다음 날", "次の日", "後一天", "ngày sau", "следующий день"),
 "your clips": ("내 클립", "自分のクリップ", "你的片段", "clip của bạn", "твои клипы"),
 "nothing yet. the camera is one tap away.": ("아직 없어요. 카메라는 한 번만 누르면 돼요.", "まだありません。カメラはワンタップで。", "還沒有。相機就在一鍵之外。", "chưa có gì. camera chỉ cách một chạm.", "пока ничего. камера в одном касании."),
 "tap + to start: create a log (new group) or join one with a code.": ("+를 눌러 시작: 로그 만들기(새 그룹) 또는 코드로 참여.", "+をタップして開始：ログを作る（新しいグループ）かコードで参加。", "點按 + 開始：建立日誌（新群組）或用代碼加入。", "nhấn + để bắt đầu: tạo log (nhóm mới) hoặc vào bằng mã.", "нажми +: создай лог (новая группа) или войди по коду."),
 "add a 2s clip every hour. see everyone's day come together.": ("매시간 2초 클립을 올려요. 모두의 하루가 하나로 모여요.", "1時間ごとに2秒のクリップ。みんなの1日がひとつになる。", "每小時新增 2 秒片段，看大家的一天合而為一。", "thêm clip 2 giây mỗi giờ. xem ngày của mọi người ghép lại.", "добавляй 2-секундный клип каждый час. смотри, как день каждого складывается в один."),
 "solo logs don't have limits. day resets at 4AM.": ("혼자 하는 로그엔 제한이 없어요. 하루는 새벽 4시에 리셋.", "ひとりログに制限なし。1日は午前4時にリセット。", "個人日誌沒有限制。一天在凌晨 4 點重置。", "log một mình không giới hạn. ngày reset lúc 4 giờ sáng.", "у сольных логов нет ограничений. день сбрасывается в 4 утра."),
 "make my first room": ("첫 방 만들기", "最初のルームを作る", "建立我的第一個房間", "tạo phòng đầu tiên", "создать первую комнату"),
 "pick your outline colour": ("테두리 색을 골라요", "枠の色を選んで", "選擇你的外框顏色", "chọn màu viền của bạn", "выбери цвет рамки"),
 "pick your colour": ("내 색 고르기", "自分の色を選ぶ", "選擇你的顏色", "chọn màu của bạn", "выбери свой цвет"),
 "change the time's font": ("시간 글꼴 바꾸기", "時刻のフォントを変える", "更改時間字型", "đổi font của giờ", "сменить шрифт времени"),
 "time font": ("시간 글꼴", "時刻のフォント", "時間字型", "font giờ", "шрифт времени"),
 "your colour": ("내 색", "自分の色", "你的顏色", "màu của bạn", "твой цвет"),
 "colour %lld": ("색 %lld", "色 %lld", "顏色 %lld", "màu %lld", "цвет %lld"),
 "just me": ("나 혼자", "自分だけ", "只有我", "chỉ mình tôi", "только я"),
 "pick a room": ("방 고르기", "ルームを選ぶ", "選擇房間", "chọn phòng", "выбери комнату"),
 "%@ is open. your two seconds?": ("%@ 열렸어요. 2초 찍을래요?", "%@ がはじまったよ。2秒撮る？", "%@ 開放了。來拍你的兩秒？", "%@ đã mở. hai giây của bạn?", "%@ открыт. твои две секунды?"),
 "%@. what's in front of you?": ("%@. 지금 눈앞엔 뭐가 있어요?", "%@。いま目の前には何がある？", "%@。你眼前有什麼？", "%@. trước mắt bạn là gì?", "%@. что сейчас перед тобой?"),
 "%lld friends": ("친구 %lld명", "友だち %lld 人", "%lld 位朋友", "%lld người bạn", "друзей: %lld"),
 "a face, a star, a squiggle, your initial. it signs every clip you take.": ("얼굴, 별, 낙서, 이니셜 뭐든요. 찍는 모든 클립에 서명이 돼요.", "顔でも星でも、ぐるぐるでもイニシャルでも。撮るクリップ全部のサインになるよ。", "一張臉、一顆星、一團塗鴉或你的縮寫。它會簽在你拍的每段片段上。", "một khuôn mặt, ngôi sao, nét nguệch ngoạc, chữ cái đầu. nó ký lên mọi clip bạn quay.", "лицо, звезда, закорючка, твоя буква. это подпись на каждом твоём клипе."),
 "a new room": ("새 방", "新しいルーム", "新房間", "phòng mới", "новая комната"),
 "a room called": ("방 이름은", "ルームの名前は", "房間名稱是", "một phòng tên là", "комната под названием"),
 "a room just for you has no limits. days turn over at 4 am.": ("나만의 방은 제한이 없어요. 하루는 새벽 4시에 넘어가요.", "自分だけのルームは制限なし。1日は朝4時に切り替わるよ。", "只屬於你的房間沒有限制。每天在凌晨 4 點換日。", "phòng chỉ cho riêng bạn thì không giới hạn. ngày mới bắt đầu lúc 4 giờ sáng.", "в комнате только для тебя нет ограничений. день сменяется в 4 утра."),
 "and then?": ("그 다음엔?", "それで？", "然後呢？", "rồi sao nữa?", "а потом?"),
 "anything you like": ("아무거나", "なんでもOK", "隨你喜歡", "tuỳ bạn", "что угодно"),
 "at night it all lines up\ninto one vlog, side by side.\nyours to keep.": ("밤이 되면 모두 나란히\n하나의 브이로그가 돼요.\n간직하는 건 당신 몫.", "夜になると全部が並んで\nひとつのVlogになる。\nあなたのものとして残るよ。", "到了晚上，全部並排\n成為一支 vlog。\n由你保存。", "đến tối, mọi thứ xếp cạnh nhau\nthành một vlog.\ncủa bạn để giữ.", "вечером всё выстраивается\nв один влог, бок о бок.\nон остаётся тебе."),
 "by continuing you agree to the [terms](%@) and [privacy policy](%@).": ("계속하면 [이용약관](%@)과 [개인정보 처리방침](%@)에 동의하게 돼요.", "続けると[利用規約](%@)と[プライバシーポリシー](%@)に同意したことになります。", "繼續即表示你同意[條款](%@)和[隱私權政策](%@)。", "tiếp tục nghĩa là bạn đồng ý với [điều khoản](%@) và [chính sách quyền riêng tư](%@).", "продолжая, ты соглашаешься с [условиями](%@) и [политикой конфиденциальности](%@)."),
 "clips only go to the room you post them in.": ("클립은 올린 방에만 보여요.", "クリップは投稿したルームにだけ届くよ。", "片段只會出現在你發布的房間裡。", "clip chỉ đến phòng bạn đăng.", "клипы видны только в комнате, куда ты их выложил."),
 "couldn't start the room. try again.": ("방을 만들지 못했어요. 다시 해 주세요.", "ルームを作れませんでした。もう一度試してね。", "無法建立房間，請再試一次。", "không tạo được phòng. thử lại nhé.", "не удалось создать комнату. попробуй ещё раз."),
 "draw": ("그려요", "描いて", "畫吧", "vẽ đi", "рисуй"),
 "draw a new mark.": ("새 마크를 그려요.", "新しいマークを描いて。", "畫一個新記號。", "vẽ dấu mới.", "нарисуй новый знак."),
 "draw it again": ("다시 그리기", "描き直す", "重畫", "vẽ lại", "нарисовать заново"),
 "draw your mark with one finger": ("한 손가락으로 마크를 그려요", "指1本でマークを描いてね", "用一根手指畫出你的記號", "vẽ dấu của bạn bằng một ngón tay", "нарисуй свой знак одним пальцем"),
 "drawing area": ("그리는 곳", "描くところ", "繪畫區域", "khu vực vẽ", "область рисования"),
 "each hour your room gets a nudge at the same minute. film two seconds of whatever is in front of you.": ("매시간 방 모두가 같은 분에 알림을 받아요. 눈앞에 있는 걸 2초만 찍어요.", "毎時、ルームのみんなに同じ分に通知が届くよ。目の前のものを2秒撮ろう。", "每小時，房間裡的人會在同一分鐘收到提醒。拍下眼前兩秒就好。", "mỗi giờ phòng bạn nhận một lời nhắc cùng một phút. quay hai giây những gì trước mắt.", "каждый час комната получает напоминание в одну и ту же минуту. сними две секунды того, что перед тобой."),
 "everyone in it gets the same nudge each hour. you'll get a code to send them.": ("방 사람들 모두 매시간 같은 알림을 받아요. 친구에게 보낼 코드를 드릴게요.", "参加者全員に毎時同じ通知が届くよ。送る用のコードも出るよ。", "裡面的每個人每小時都會收到同一個提醒。你會拿到一組代碼傳給他們。", "mọi người trong phòng nhận cùng một lời nhắc mỗi giờ. bạn sẽ có mã để gửi cho họ.", "все в комнате получают одно и то же напоминание каждый час. ты получишь код, чтобы отправить им."),
 "film as much as you like, whenever. only you see it.": ("원할 때 원하는 만큼 찍어요. 나만 볼 수 있어요.", "好きなときに好きなだけ撮ってね。見られるのはあなただけ。", "隨時想拍多少就拍多少，只有你看得到。", "quay bao nhiêu tuỳ thích, lúc nào cũng được. chỉ bạn thấy.", "снимай сколько хочешь и когда хочешь. видишь только ты."),
 "flash off": ("플래시 끔", "フラッシュ オフ", "閃光燈關閉", "tắt đèn flash", "вспышка выкл."),
 "flash on": ("플래시 켬", "フラッシュ オン", "閃光燈開啟", "bật đèn flash", "вспышка вкл."),
 "for me +": ("나 +", "わたし +", "我 +", "mình +", "я +"),
 "friends see this on your clips. you can redraw it any time in your profile.": ("친구들은 당신 클립에서 이걸 봐요. 프로필에서 언제든 다시 그릴 수 있어요.", "友だちはあなたのクリップでこれを見るよ。プロフィールからいつでも描き直せるよ。", "朋友會在你的片段上看到它。隨時可以在個人檔案重畫。", "bạn bè thấy dấu này trên clip của bạn. vẽ lại bất cứ lúc nào trong hồ sơ.", "друзья видят его на твоих клипах. перерисовать можно в профиле в любой момент."),
 "friends.": ("명의 친구.", "人の友だち。", "位朋友。", "người bạn.", "друзей."),
 "got %@. next nudge in %@": ("%@ 찍었어요. 다음 알림까지 %@", "%@ 撮れた。次の通知まで %@", "%@ 拍好了。下一次提醒在 %@ 後", "đã có %@. lời nhắc tiếp theo sau %@", "%@ есть. следующее напоминание через %@"),
 "hourly nudges": ("매시간 알림", "毎時の通知", "每小時提醒", "nhắc mỗi giờ", "напоминания каждый час"),
 "it goes under your clips.": ("클립 아래에 표시돼요.", "クリップの下に表示されるよ。", "它會顯示在你的片段下方。", "tên sẽ hiện dưới clip của bạn.", "оно будет под твоими клипами."),
 "join with a code": ("코드로 참여", "コードで参加", "用代碼加入", "vào bằng mã", "войти по коду"),
 "just for me.": ("나만을 위한.", "わたしだけの。", "只給我自己。", "chỉ cho mình.", "только для меня."),
 "meet %@.": ("안녕, %@.", "はじめまして、%@。", "你好，%@。", "chào %@.", "знакомься: %@."),
 "most of a day never gets filmed.\nthe walk, the lunch, the 11 pm kitchen.\nthose were the good parts.": ("하루의 대부분은 찍히지 않아요.\n걷던 길, 점심, 밤 11시의 부엌.\n그게 좋은 순간들이었는데.", "1日のほとんどは撮られないまま。\n帰り道、お昼ごはん、夜11時の台所。\nそれがいい瞬間だったのに。", "一天的大部分都沒被拍下來。\n散步、午餐、晚上 11 點的廚房。\n那些才是美好的片刻。", "phần lớn một ngày chẳng ai quay lại.\nlúc đi bộ, bữa trưa, căn bếp lúc 11 giờ đêm.\nđó mới là những phần đẹp.", "большая часть дня никогда не попадает в кадр.\nпрогулка, обед, кухня в 11 вечера.\nа ведь это и было самое хорошее."),
 "next": ("다음", "次へ", "下一步", "tiếp", "дальше"),
 "next nudge in %@": ("다음 알림까지 %@", "次の通知まで %@", "下一次提醒在 %@ 後", "lời nhắc tiếp theo sau %@", "следующее напоминание через %@"),
 "no ads, no streaks, no \"you missed it\".": ("광고도, 연속 기록도, \"놓쳤어요\"도 없어요.", "広告も連続記録も「見逃したよ」もなし。", "沒有廣告、沒有連續紀錄、沒有「你錯過了」。", "không quảng cáo, không chuỗi ngày, không \"bạn đã bỏ lỡ\".", "без рекламы, без серий, без «ты пропустил»."),
 "no nudges yet. rooms with friends get one every hour.": ("아직 알림이 없어요. 친구와 함께하는 방은 매시간 알림을 받아요.", "まだ通知はないよ。友だちとのルームには毎時届くよ。", "還沒有提醒。和朋友一起的房間每小時都會收到一次。", "chưa có lời nhắc nào. phòng có bạn bè sẽ nhận mỗi giờ.", "напоминаний пока нет. комнаты с друзьями получают их каждый час."),
 "not now": ("나중에", "あとで", "現在不要", "để sau", "не сейчас"),
 "now draw your mark.": ("이제 당신의 마크를 그려요.", "つぎはあなたのマークを描いて。", "現在畫出你的記號。", "giờ hãy vẽ dấu của bạn.", "теперь нарисуй свой знак."),
 "nudges": ("알림", "通知", "提醒", "lời nhắc", "напоминания"),
 "okay": ("좋아요", "うん", "好", "được", "ок"),
 "once an hour, everyone in your room\ngets the same nudge.\ntwo seconds. one take. no redo.": ("한 시간에 한 번, 방 모두가\n같은 알림을 받아요.\n2초. 한 번. 다시 찍기 없음.", "1時間に1回、ルームのみんなに\n同じ通知が届く。\n2秒。1テイク。撮り直しなし。", "每小時一次，房間裡的每個人\n收到同一個提醒。\n兩秒。一次拍。不能重拍。", "mỗi giờ một lần, cả phòng bạn\nnhận cùng một lời nhắc.\nhai giây. một lần quay. không quay lại.", "раз в час все в твоей комнате\nполучают одно напоминание.\nдве секунды. один дубль. без пересъёмки."),
 "one nudge an hour.\nsame minute as your friends,\nso you all film the same moment.": ("한 시간에 알림 하나.\n친구들과 같은 분에 와서,\n모두가 같은 순간을 찍어요.", "1時間に1回の通知。\n友だちと同じ分に届くから、\nみんなで同じ瞬間を撮れる。", "每小時一次提醒。\n和朋友同一分鐘，\n大家拍下同一個時刻。", "mỗi giờ một lời nhắc.\ncùng phút với bạn bè,\nnên mọi người quay cùng một khoảnh khắc.", "одно напоминание в час.\nв ту же минуту, что и у друзей,\nчтобы вы снимали один и тот же момент."),
 "only you": ("나만", "わたしだけ", "只有你", "chỉ bạn", "только ты"),
 "page %lld of %lld": ("%lld / %lld 페이지", "%lld / %lld ページ", "第 %lld / %lld 頁", "trang %lld / %lld", "страница %lld из %lld"),
 "redraw": ("다시 그리기", "描き直す", "重畫", "vẽ lại", "перерисовать"),
 "save it": ("저장", "保存", "儲存", "lưu lại", "сохранить"),
 "saved on your phone. it'll post when you're back online.": ("휴대폰에 저장했어요. 다시 연결되면 올라가요.", "スマホに保存したよ。オンラインに戻ったら投稿されるよ。", "已存到你的手機。恢復連線後就會發布。", "đã lưu trên điện thoại. sẽ đăng khi bạn có mạng lại.", "сохранено на телефоне. опубликуется, когда вернётся связь."),
 "start a\nroom": ("방\n만들기", "ルームを\nつくる", "開一個\n房間", "tạo\nphòng", "создать\nкомнату"),
 "start a room": ("방 만들기", "ルームをつくる", "開一個房間", "tạo phòng", "создать комнату"),
 "start it": ("시작하기", "はじめる", "開始", "bắt đầu", "начать"),
 "start my first room": ("첫 방 만들기", "最初のルームをつくる", "開我的第一個房間", "tạo phòng đầu tiên", "создать первую комнату"),
 "start over": ("처음부터", "最初から", "重來", "làm lại", "начать сначала"),
 "sure": ("좋아요", "いいよ", "好啊", "được thôi", "давай"),
 "tap + to start a room with friends, or join one with a code.": ("+를 눌러 친구와 방을 만들거나, 코드로 참여해요.", "＋をタップして友だちとルームをつくるか、コードで参加しよう。", "點 + 和朋友開一個房間，或用代碼加入。", "chạm + để tạo phòng với bạn bè, hoặc vào bằng mã.", "нажми +, чтобы создать комнату с друзьями или войти по коду."),
 "tap anywhere": ("아무 데나 눌러요", "どこかをタップ", "點任何地方", "chạm vào đâu cũng được", "нажми где угодно"),
 "tap to film": ("눌러서 찍기", "タップで撮影", "點一下拍攝", "chạm để quay", "нажми, чтобы снять"),
 "that's me": ("이게 나예요", "これがわたし", "這就是我", "là mình đó", "это я"),
 "this page is yours. nobody else sees what you write here.": ("이 페이지는 당신 거예요. 여기 쓴 건 아무도 못 봐요.", "このページはあなただけのもの。ここに書いたことは誰にも見えないよ。", "這一頁是你的。你寫在這裡的，別人都看不到。", "trang này là của bạn. không ai khác thấy những gì bạn viết ở đây.", "эта страница твоя. никто не видит, что ты здесь пишешь."),
 "tips: your day lives on the left, the camera is in the middle, start a room on the right. tap to close.": ("팁: 왼쪽은 오늘 페이지, 가운데는 카메라, 오른쪽에서 방을 만들어요. 눌러서 닫기.", "ヒント：左に今日のページ、真ん中にカメラ、右でルームをつくれるよ。タップで閉じる。", "提示：左邊是你的一天，中間是相機，右邊可以開房間。點一下關閉。", "mẹo: bên trái là ngày của bạn, giữa là camera, bên phải để tạo phòng. chạm để đóng.", "подсказка: слева твой день, в центре камера, справа создать комнату. нажми, чтобы закрыть."),
 "turn me sideways": ("옆으로 돌려요", "横にしてね", "把我轉橫", "xoay ngang nhé", "поверни меня боком"),
 "undo": ("실행 취소", "取り消す", "復原", "hoàn tác", "отменить"),
 "untitled room": ("이름 없는 방", "名前のないルーム", "未命名房間", "phòng chưa đặt tên", "комната без названия"),
 "up to 19 friends": ("최대 19명의 친구", "友だち最大19人", "最多 19 位朋友", "tối đa 19 người bạn", "до 19 друзей"),
 "what happened today?": ("오늘 무슨 일이 있었어요?", "今日は何があった？", "今天發生了什麼？", "hôm nay có gì?", "что сегодня было?"),
 "with friends": ("친구와", "友だちと", "和朋友", "với bạn bè", "с друзьями"),
 "your camera and mic,\nonly while you're filming.": ("카메라와 마이크,\n찍는 동안에만 써요.", "カメラとマイク、\n撮っているあいだだけ。", "你的相機和麥克風，\n只在拍攝時使用。", "camera và mic của bạn,\nchỉ khi bạn đang quay.", "твоя камера и микрофон,\nтолько пока ты снимаешь."),
 "your day\nlives here": ("오늘은\n여기 있어요", "今日は\nここにあるよ", "你的一天\n在這裡", "ngày của bạn\nở đây", "твой день\nживёт здесь"),
 "your mark": ("나의 마크", "わたしのマーク", "我的記號", "dấu của bạn", "твой знак"),
 "couldn't send that. try again.": ("보내지 못했어요. 다시 해 주세요.", "送信できませんでした。もう一度試してね。", "無法送出，請再試一次。", "không gửi được. thử lại nhé.", "не удалось отправить. попробуй ещё раз."),
 "friend": ("친구", "ともだち", "朋友", "bạn", "друг"),
 "it goes under your clips. optional: you can skip it and change it later.": ("클립 아래에 표시돼요. 선택 사항이라 건너뛰고 나중에 바꿔도 돼요.", "クリップの下に表示されるよ。任意なのでスキップして後で変えてもOK。", "它會顯示在你的片段下方。可選填，可以先跳過，之後再改。", "tên hiện dưới clip của bạn. không bắt buộc: có thể bỏ qua và đổi sau.", "оно будет под твоими клипами. необязательно: можно пропустить и поменять позже."),
 "report %@": ("%@님 신고", "%@ を報告", "檢舉 %@", "báo cáo %@", "пожаловаться на %@"),
 "skip": ("건너뛰기", "スキップ", "跳過", "bỏ qua", "пропустить"),
 "thanks. we'll look at it within a day.": ("고마워요. 하루 안에 확인할게요.", "ありがとう。1日以内に確認するね。", "謝謝，我們會在一天內處理。", "cảm ơn. chúng tôi sẽ xem trong vòng một ngày.", "спасибо. посмотрим в течение суток."),
 "what's wrong?": ("무슨 문제인가요?", "どうしたの？", "有什麼問題？", "có vấn đề gì?", "что не так?"),
 "your clips, your rooms, and your sign-in are removed from vlogify's servers. friends keep their own clips. to also stop using Sign in with Apple for vlogify, open Settings > your name > Sign in with Apple.": ("클립, 방, 로그인 정보가 vlogify 서버에서 삭제돼요. 친구들은 자기 클립을 그대로 가져요. vlogify의 Apple로 로그인 사용도 멈추려면 설정 > 내 이름 > Apple로 로그인으로 가세요.", "クリップ、ルーム、サインイン情報がvlogifyのサーバーから削除されます。友だちは自分のクリップを持ち続けます。vlogifyでのAppleでサインインもやめるには、設定 > あなたの名前 > Appleでサインイン を開いてください。", "你的片段、房間與登入資料會從 vlogify 的伺服器刪除。朋友會保留他們自己的片段。若也要停止在 vlogify 使用「以 Apple 登入」，請前往 設定 > 你的名字 > 以 Apple 登入。", "clip, phòng và thông tin đăng nhập của bạn sẽ bị xoá khỏi máy chủ vlogify. bạn bè vẫn giữ clip của họ. để ngừng dùng Đăng nhập bằng Apple cho vlogify, mở Cài đặt > tên của bạn > Đăng nhập bằng Apple.", "твои клипы, комнаты и данные входа удаляются с серверов vlogify. у друзей остаются их клипы. чтобы перестать входить в vlogify через Apple, открой Настройки > твоё имя > Вход с Apple."),
}
# Identical in every language: identifiers, placeholders, the brand.
SAME = {"google", "email", "", "000000", "ABC-123", "you@example.com", "vlogify", "no camera in the simulator"}

INFO = {
 "CFBundleDisplayName": ("vlogify",)*5,
 "CFBundleName": ("vlogify",)*5,
 "NSCameraUsageDescription": (
   "vlogify는 매시간 방에 올릴 2초 클립을 찍기 위해 카메라를 사용해요.",
   "vlogifyは、1時間ごとにルームへ追加する2秒クリップを撮影するためにカメラを使用します。",
   "vlogify 使用相機來錄製你每小時新增到房間的 2 秒片段。",
   "vlogify dùng camera để quay clip 2 giây bạn thêm vào phòng mỗi giờ.",
   "vlogify использует камеру, чтобы записать 2-секундный клип, который ты добавляешь в комнату каждый час."),
 "NSMicrophoneUsageDescription": (
   "vlogify는 친구들이 그 순간을 보기만이 아니라 들을 수 있도록 클립과 함께 소리를 녹음해요.",
   "vlogifyは、友だちがその瞬間を見るだけでなく聞けるように、クリップと一緒に音声を録音します。",
   "vlogify 會隨每段片段錄製聲音，讓朋友不只看見、也聽見那一刻。",
   "vlogify ghi âm cùng mỗi clip để bạn bè nghe được khoảnh khắc, không chỉ nhìn.",
   "vlogify записывает звук с каждым клипом, чтобы друзья слышали момент, а не только видели."),
 "NSPhotoLibraryAddUsageDescription": (
   "내보내기를 누르면 완성된 하루 브이로그를 사진에 저장해요. 사진 보관함을 읽지는 않아요.",
   "書き出しをタップすると完成した1日のVlogを写真に保存します。ライブラリを読み取ることはありません。",
   "點按匯出時，vlogify 會將完成的一日 vlog 儲存到照片。它不會讀取你的圖庫。",
   "vlogify lưu vlog cả ngày đã hoàn thành vào Ảnh khi bạn nhấn xuất. Không bao giờ đọc thư viện của bạn.",
   "vlogify сохраняет готовый влог дня в Фото, когда ты нажимаешь «экспорт». Библиотеку он никогда не читает."),
}

LANGS = ["ko", "ja", "zh-Hant", "vi", "ru"]
REVIEW = {"ja", "zh-Hant", "vi", "ru"}

def catalog(keys, table, same=set()):
    strings = {}
    missing = []
    for key in sorted(keys):
        entry = {"localizations": {"en": {"stringUnit": {"state": "translated", "value": key}}}}
        if key in same:
            for lang in LANGS:
                entry["localizations"][lang] = {"stringUnit": {"state": "translated", "value": key}}
        elif key in table:
            for lang, value in zip(LANGS, table[key]):
                entry["localizations"][lang] = {"stringUnit": {"state": "needs_review" if lang in REVIEW else "translated", "value": value}}
        else:
            missing.append(key)
        strings[key] = entry
    return {"sourceLanguage": "en", "version": "1.0", "strings": strings}, missing

xliff = subprocess.run(["bash", "-c", "find build/loc -name en.xliff | head -1"], capture_output=True, text=True).stdout.strip()
if not xliff:
    sys.exit("run: xcodebuild -exportLocalizations -project ios/Vlogify.xcodeproj -scheme Vlogify -localizationPath build/loc -exportLanguage en -derivedDataPath build/loc-dd")
import xml.etree.ElementTree as ET
ns = {"x": "urn:oasis:names:tc:xliff:document:1.2"}
root = ET.parse(xliff).getroot()
keys = []
for f in root.findall("x:file", ns):
    if "Localizable" in f.get("original"):
        keys = [u.get("id") for u in f.findall(".//x:trans-unit", ns)]

loc, missing = catalog(keys, T, SAME)
json.dump(loc, open("ios/Vlogify/Resources/Localizable.xcstrings", "w"), ensure_ascii=False, indent=2)
info_keys = ["CFBundleDisplayName", "CFBundleName", "NSCameraUsageDescription", "NSMicrophoneUsageDescription", "NSPhotoLibraryAddUsageDescription"]
# Info.plist source values come from project.yml; the catalog needs the English text as the value, not the key.
plist_en = {}
for f in root.findall("x:file", ns):
    if "InfoPlist" in f.get("original"):
        for u in f.findall(".//x:trans-unit", ns):
            plist_en[u.get("id")] = u.find("x:source", ns).text
info = {"sourceLanguage": "en", "version": "1.0", "strings": {}}
for key in info_keys:
    entry = {"localizations": {"en": {"stringUnit": {"state": "translated", "value": plist_en.get(key, key)}}}}
    for lang, value in zip(LANGS, INFO[key]):
        entry["localizations"][lang] = {"stringUnit": {"state": "needs_review" if lang in REVIEW else "translated", "value": value}}
    info["strings"][key] = entry
json.dump(info, open("ios/Vlogify/Resources/InfoPlist.xcstrings", "w"), ensure_ascii=False, indent=2)
print(f"{len(keys)} keys, {len(missing)} untranslated")
for m in missing: print("  MISSING:", repr(m))
