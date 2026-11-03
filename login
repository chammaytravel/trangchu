/* =====================================================================
   CHẠM MÂY TRAVEL: Đăng nhập, tạo tài khoản và bình luận
   Dùng Supabase Auth + bảng public.comments trong chính database hiện có.
   Cách dùng: đặt file này cạnh index.html và thêm MỘT dòng ngay trước </body>:
       <script src="./auth-comments.js"></script>
   (phải nằm SAU đoạn <script> chính, nơi khai báo supabaseClient)
   Bảng comments + chính sách bảo mật tạo bằng file supabase-comments.sql.
   ===================================================================== */
(function () {
  "use strict";
  if (typeof supabaseClient === "undefined" || !supabaseClient || !supabaseClient.auth) {
    console.warn("auth-comments.js: không thấy supabaseClient, tính năng đăng nhập/bình luận chưa chạy.");
    return;
  }
  var sb = supabaseClient;
  var COMMENT_MAX = 1000, COOLDOWN_MS = 10000, PAGE_SIZE = 60;
  var user = null, mode = "login", lastPost = 0, mountedKey = "";

  var $ = function (s, r) { return (r || document).querySelector(s); };
  var el = function (tag, cls, txt) { var e = document.createElement(tag); if (cls) e.className = cls; if (txt !== undefined) e.textContent = txt; return e; };
  var nameOf = function (u) { return (u && u.user_metadata && u.user_metadata.display_name) || (u && u.email ? u.email.split("@")[0] : "Thành viên"); };
  var validEmail = function (v) { return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v); };

  /* ---------- CSS ---------- */
  var css = [
    ".auth-wrap{position:relative;display:flex;align-items:center}",
    ".auth-btn{display:inline-flex;align-items:center;gap:8px;height:42px;padding:0 14px;border:1.5px solid currentColor;border-radius:999px;background:transparent;color:inherit;font:600 15px 'Be Vietnam Pro',sans-serif;cursor:pointer;white-space:nowrap;transition:background .3s,transform .45s var(--e)}",
    ".auth-btn:hover{background:rgba(140,106,63,.22);transform:translateY(-2px)}",
    ".auth-btn svg{width:19px;height:19px;flex:none}",
    ".auth-av{width:26px;height:26px;border-radius:50%;background:var(--ac);color:var(--on);display:grid;place-items:center;font:700 13px 'Be Vietnam Pro',sans-serif;flex:none}",
    ".auth-lbl{max-width:120px;overflow:hidden;text-overflow:ellipsis}",
    "@media(max-width:760px){.auth-btn{width:42px;padding:0;justify-content:center}.auth-lbl{display:none}.auth-btn.in{padding:0}}",
    ".auth-menu{position:absolute;right:0;top:calc(100% + 10px);min-width:230px;background:var(--bg);color:var(--tx);border:1px solid var(--line);border-radius:12px;box-shadow:var(--sh);padding:12px;z-index:40}",
    ".auth-menu[hidden]{display:none}",
    ".auth-me{padding:4px 6px 10px;border-bottom:1px solid var(--line);margin-bottom:8px}.auth-me b{display:block}.auth-me span{display:block;font-size:13px;color:var(--sub);overflow-wrap:anywhere}",
    ".auth-menu button{width:100%;text-align:left;background:none;border:0;color:inherit;font:inherit;padding:9px 6px;border-radius:8px;cursor:pointer}.auth-menu button:hover{background:var(--card)}",
    "#auth-dlg{max-width:min(440px,94vw)}",
    ".auth-top{display:flex;justify-content:space-between;align-items:center;gap:12px;margin-bottom:6px}.auth-top h2{margin:0;font-size:1.6rem}",
    ".auth-x{width:40px;height:40px;border-radius:50%;border:1.5px solid var(--line);background:none;color:inherit;font-size:22px;line-height:1;cursor:pointer}.auth-x:hover{border-color:var(--ac)}",
    ".auth-tabs{display:flex;gap:8px;margin:12px 0 16px}",
    ".auth-tabs button{flex:1;padding:9px 12px;border-radius:999px;border:1.5px solid var(--sub);background:transparent;color:var(--tx);font:600 15px 'Be Vietnam Pro',sans-serif;cursor:pointer;transition:background .3s,color .3s}",
    ".auth-tabs button[aria-selected=true]{background:var(--tx);color:var(--bg);border-color:var(--tx)}",
    "#auth-form{display:grid;gap:12px}#auth-form[hidden],#auth-form label[hidden]{display:none}",
    "#auth-dlg input[type=password],#auth-dlg input[type=text]{font:inherit;padding:11px 14px;border:1.5px solid var(--sub);background:var(--bg);color:var(--tx);border-radius:8px;width:100%}",
    "#auth-dlg input:focus{outline:none;border-color:var(--ac);box-shadow:0 0 0 4px rgba(140,61,15,.16)}",
    ".auth-show{display:flex;align-items:center;gap:8px;font-size:14px;color:var(--sub);cursor:pointer}.auth-show input{accent-color:var(--ac)}",
    ".auth-fine{font-size:13px;color:var(--sub);margin:14px 0 0;max-width:none}",
    ".cmt{max-width:760px;margin:44px 0 0;padding-top:28px;border-top:2px solid var(--tx)}",
    ".cmt h2{font-size:clamp(1.4rem,2.6vw,1.9rem);margin:0 0 14px}.cmt h2 span{color:var(--sub);font-weight:500;font-size:.8em}",
    ".cmt-box{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:16px 18px;margin-bottom:20px}",
    ".cmt-box p{margin:0 0 12px;max-width:none}",
    ".cmt-form textarea{min-height:100px;resize:vertical}",
    ".cmt-row{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap;margin-top:10px}",
    ".cmt-count{font-size:13px;color:var(--sub)}",
    ".cmt-msg{margin:10px 0 0}",
    ".cmt-item{display:grid;grid-template-columns:auto 1fr;gap:6px 14px;padding:16px 0;border-bottom:1px solid var(--line)}",
    ".cmt-av{grid-row:span 2;width:40px;height:40px;border-radius:50%;background:var(--ac);color:var(--on);display:grid;place-items:center;font:700 16px 'Be Vietnam Pro',sans-serif}",
    ".cmt-head{display:flex;flex-wrap:wrap;gap:4px 12px;align-items:baseline}.cmt-head b{font-weight:600}.cmt-head time{font-size:13px;color:var(--sub)}",
    ".cmt-body{margin:0;white-space:pre-wrap;overflow-wrap:anywhere;max-width:none}",
    ".cmt-del{justify-self:start;background:none;border:0;color:var(--ac2);font:inherit;font-size:13px;text-decoration:underline;cursor:pointer;padding:0;margin-top:4px}",
    ".cmt-empty{color:var(--sub);padding:10px 0}"
  ].join("\n");
  var st = document.createElement("style"); st.id = "auth-comments-css"; st.textContent = css; document.head.appendChild(st);

  /* ---------- Hộp thoại đăng nhập / tạo tài khoản ---------- */
  var dlg = document.createElement("dialog");
  dlg.id = "auth-dlg"; dlg.setAttribute("aria-labelledby", "auth-title");
  dlg.innerHTML =
    '<div class="auth-top"><h2 id="auth-title">Đăng nhập</h2><button type="button" class="auth-x" aria-label="Đóng">×</button></div>' +
    '<div class="auth-tabs" role="tablist" aria-label="Đăng nhập hoặc tạo tài khoản">' +
    '<button type="button" role="tab" data-m="login" aria-selected="true">Đăng nhập</button>' +
    '<button type="button" role="tab" data-m="signup" aria-selected="false">Tạo tài khoản</button></div>' +
    '<form id="auth-form" novalidate>' +
    '<label class="f" id="auth-name-wrap" hidden>Tên hiển thị<input type="text" id="auth-name" maxlength="40" autocomplete="nickname"><span class="err" data-e="name"></span></label>' +
    '<label class="f">Email<input type="email" id="auth-email" autocomplete="email"><span class="err" data-e="email"></span></label>' +
    '<label class="f">Mật khẩu<input type="password" id="auth-pass" autocomplete="current-password"><span class="err" data-e="pass"></span></label>' +
    '<label class="auth-show"><input type="checkbox" id="auth-show"> Hiện mật khẩu</label>' +
    '<div id="auth-msg" role="status" aria-live="polite"></div>' +
    '<button class="btn" type="submit" id="auth-go">Đăng nhập</button></form>' +
    '<p class="auth-fine" id="auth-fine"></p>';
  document.body.appendChild(dlg);

  function setErr(k, m) { var s = dlg.querySelector('[data-e="' + k + '"]'); if (s) s.textContent = m || ""; }
  function setMode(m) {
    mode = m;
    var su = m === "signup";
    $("#auth-title").textContent = su ? "Tạo tài khoản" : "Đăng nhập";
    $("#auth-go").textContent = su ? "Tạo tài khoản" : "Đăng nhập";
    $("#auth-name-wrap").hidden = !su;
    $("#auth-pass").setAttribute("autocomplete", su ? "new-password" : "current-password");
    dlg.querySelectorAll(".auth-tabs button").forEach(function (b) { b.setAttribute("aria-selected", String(b.dataset.m === m)); });
    $("#auth-msg").replaceChildren(); ["name", "email", "pass"].forEach(function (k) { setErr(k, ""); });
    var fine = $("#auth-fine"); fine.replaceChildren();
    fine.append(document.createTextNode(su
      ? "Email chỉ dùng để đăng nhập. Tên hiển thị sẽ xuất hiện cạnh bình luận của bạn. Khi tạo tài khoản, bạn đồng ý với "
      : "Chưa có tài khoản? Chọn “Tạo tài khoản” ở trên. Bạn dùng tài khoản này để bình luận. Xem "));
    var a1 = el("a", "", "Điều khoản"); a1.href = "#/chinh-sach/dieu-khoan";
    var a2 = el("a", "", "Chính sách bảo mật"); a2.href = "#/chinh-sach/bao-mat";
    fine.append(a1, document.createTextNode(" và "), a2, document.createTextNode("."));
  }
  function openAuth(m) {
    setMode(m || "login");
    if (typeof dlg.showModal === "function") { if (!dlg.open) dlg.showModal(); } else dlg.setAttribute("open", "");
    setTimeout(function () { var f = m === "signup" ? $("#auth-name") : $("#auth-email"); if (f) f.focus(); }, 30);
  }
  function closeAuth() { if (dlg.open) dlg.close(); }
  dlg.querySelector(".auth-x").addEventListener("click", closeAuth);
  dlg.addEventListener("click", function (e) { if (e.target === dlg) closeAuth(); });
  dlg.querySelector(".auth-tabs").addEventListener("click", function (e) { var b = e.target.closest("button[data-m]"); if (b) setMode(b.dataset.m); });
  $("#auth-show").addEventListener("change", function (e) { $("#auth-pass").type = e.target.checked ? "text" : "password"; });
  dlg.addEventListener("close", function () { $("#auth-pass").value = ""; $("#auth-pass").type = "password"; $("#auth-show").checked = false; });

  function authMsg(text, ok) {
    var box = $("#auth-msg"); box.replaceChildren();
    if (text) { var d = el("div", "msg", text); if (ok) d.style.borderLeftColor = "var(--sub)"; box.append(d); }
  }
  function mapAuthError(err) {
    var m = String((err && err.message) || "").toLowerCase();
    if (m.indexOf("invalid login") > -1) return "Email hoặc mật khẩu chưa đúng.";
    if (m.indexOf("not confirmed") > -1) return "Email chưa được xác nhận. Hãy mở email xác nhận mà Chạm Mây đã gửi rồi đăng nhập lại.";
    if (m.indexOf("already") > -1 || m.indexOf("registered") > -1) return "Email này đã có tài khoản. Hãy chuyển sang “Đăng nhập”.";
    if (m.indexOf("password") > -1 && (m.indexOf("least") > -1 || m.indexOf("weak") > -1 || m.indexOf("short") > -1)) return "Mật khẩu quá yếu hoặc quá ngắn. Hãy dùng ít nhất 8 ký tự.";
    if (m.indexOf("rate") > -1 || m.indexOf("too many") > -1 || m.indexOf("seconds") > -1) return "Bạn thao tác quá nhanh. Hãy chờ một lát rồi thử lại.";
    if (m.indexOf("signups not allowed") > -1 || m.indexOf("disabled") > -1) return "Máy chủ đang tắt tính năng đăng nhập bằng email.";
    if (m.indexOf("fetch") > -1 || m.indexOf("network") > -1) return "Không kết nối được máy chủ. Kiểm tra mạng và thử lại.";
    return "Chưa xử lý được yêu cầu. Hãy thử lại sau.";
  }
  $("#auth-form").addEventListener("submit", async function (e) {
    e.preventDefault();
    var name = $("#auth-name").value.trim(), email = $("#auth-email").value.trim().toLowerCase(), pass = $("#auth-pass").value;
    var bad = false, su = mode === "signup";
    ["name", "email", "pass"].forEach(function (k) { setErr(k, ""); }); authMsg("");
    if (su && (name.length < 2 || name.length > 40)) { setErr("name", "Tên hiển thị cần từ 2 đến 40 ký tự."); bad = true; }
    if (!validEmail(email)) { setErr("email", "Email chưa đúng định dạng, ví dụ ten@email.com."); bad = true; }
    if (pass.length < 8) { setErr("pass", "Mật khẩu cần ít nhất 8 ký tự."); bad = true; }
    if (bad) return;
    var btn = $("#auth-go"), old = btn.textContent; btn.disabled = true; btn.textContent = "Đang xử lý…";
    try {
      if (su) {
        var r = await sb.auth.signUp({ email: email, password: pass, options: { data: { display_name: name } } });
        if (r.error) throw r.error;
        if (r.data && r.data.user && r.data.user.identities && r.data.user.identities.length === 0) { authMsg("Email này đã có tài khoản. Hãy chuyển sang “Đăng nhập”."); }
        else if (r.data && r.data.session) { closeAuth(); toast("Chào " + name + ", tài khoản của bạn đã sẵn sàng."); }
        else { authMsg("Đã tạo tài khoản. Hãy mở email xác nhận để kích hoạt, sau đó quay lại đăng nhập.", true); }
      } else {
        var r2 = await sb.auth.signInWithPassword({ email: email, password: pass });
        if (r2.error) throw r2.error;
        closeAuth(); toast("Đã đăng nhập.");
      }
    } catch (err) {
      console.error("Auth error:", err); authMsg(mapAuthError(err));
    } finally { btn.disabled = false; btn.textContent = old; }
  });

  /* ---------- Thông báo nhỏ ---------- */
  var toastEl = null, toastT = 0;
  function toast(msg) {
    if (!toastEl) {
      toastEl = el("div", "msg"); toastEl.setAttribute("role", "status");
      toastEl.style.cssText = "position:fixed;left:50%;bottom:24px;transform:translateX(-50%);z-index:60;max-width:92vw;box-shadow:var(--sh);margin:0";
      document.body.appendChild(toastEl);
    }
    toastEl.textContent = msg; toastEl.hidden = false; clearTimeout(toastT);
    toastT = setTimeout(function () { toastEl.hidden = true; }, 3800);
  }

  /* ---------- Nút tài khoản trên header ---------- */
  var ICON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.6-7 8-7s8 3 8 7"/></svg>';
  var wrap = null, btnA = null, menu = null;
  function buildHeader() {
    var rt = $(".rt"); if (!rt || $("#auth-wrap")) return;
    wrap = el("div", "auth-wrap"); wrap.id = "auth-wrap";
    btnA = el("button", "auth-btn"); btnA.type = "button"; btnA.id = "auth-btn";
    menu = el("div", "auth-menu"); menu.id = "auth-menu"; menu.hidden = true;
    wrap.append(btnA, menu);
    rt.insertBefore(wrap, $("#burger"));
    btnA.addEventListener("click", function () {
      if (!user) { openAuth("login"); return; }
      var open = menu.hidden; menu.hidden = !open; btnA.setAttribute("aria-expanded", String(open));
    });
    document.addEventListener("click", function (e) { if (user && !wrap.contains(e.target)) { menu.hidden = true; btnA.setAttribute("aria-expanded", "false"); } });
    document.addEventListener("keydown", function (e) { if (e.key === "Escape" && menu && !menu.hidden) { menu.hidden = true; btnA.focus(); } });
  }
  function renderAuthUI() {
    buildHeader(); if (!btnA) return;
    btnA.replaceChildren(); menu.replaceChildren(); menu.hidden = true;
    if (user) {
      var n = nameOf(user), av = el("span", "auth-av", n.trim().charAt(0).toUpperCase() || "?");
      var lbl = el("span", "auth-lbl", n);
      btnA.classList.add("in"); btnA.setAttribute("aria-haspopup", "menu"); btnA.setAttribute("aria-expanded", "false");
      btnA.setAttribute("aria-label", "Tài khoản của " + n); btnA.append(av, lbl);
      var me = el("div", "auth-me"); me.append(el("b", "", n), el("span", "", user.email || ""));
      var out = el("button", "", "Đăng xuất"); out.type = "button";
      out.addEventListener("click", async function () { menu.hidden = true; var r = await sb.auth.signOut(); if (r.error) toast("Chưa đăng xuất được, hãy thử lại."); else toast("Đã đăng xuất."); });
      menu.append(me, out);
    } else {
      btnA.classList.remove("in"); btnA.removeAttribute("aria-haspopup"); btnA.removeAttribute("aria-expanded");
      btnA.setAttribute("aria-label", "Đăng nhập hoặc tạo tài khoản");
      btnA.insertAdjacentHTML("beforeend", ICON); btnA.append(el("span", "auth-lbl", "Đăng nhập"));
    }
  }
  function prefillForms() {
    if (!user) return;
    var set = function (id, v) { var i = $(id); if (i && !i.value && v) i.value = v; };
    set("#c-name", nameOf(user)); set("#c-mail", user.email); set("#r-name", nameOf(user));
  }

  /* ---------- Bình luận ---------- */
  function target() {
    var p = (location.hash.replace(/^#/, "") || "/").split("/").filter(Boolean);
    if (p[0] === "cam-nang" && p[1]) return { key: "guide:" + p[1], host: $("#guide-article .guide-next") };
    if (p[0] === "kham-pha-hue" && p[1]) return { key: "place:" + p[1], host: $("#place-box .pn") };
    return null;
  }
  function fmtTime(s) { try { return new Date(s).toLocaleString("vi-VN", { dateStyle: "short", timeStyle: "short" }); } catch (e) { return ""; } }
  function mapDbError(err) {
    var c = err && (err.code || ""), m = String((err && err.message) || "").toLowerCase();
    if (c === "42P01" || c === "PGRST205" || m.indexOf("schema cache") > -1 || m.indexOf("does not exist") > -1) return "Tính năng bình luận chưa được bật trên máy chủ (cần chạy file supabase-comments.sql).";
    if (c === "42501" || m.indexOf("row-level security") > -1 || m.indexOf("jwt") > -1) return "Phiên đăng nhập đã hết hạn hoặc chưa có quyền. Hãy đăng nhập lại.";
    if (c === "23514") return "Bình luận cần từ 2 đến " + COMMENT_MAX + " ký tự.";
    return "Chưa gửi được bình luận. Hãy thử lại sau.";
  }
  function mount() {
    var old = $("#cmt"); if (old) old.remove();
    var t = target(); mountedKey = ""; if (!t || !t.host) return;
    mountedKey = t.key;
    var sec = el("section", "cmt"); sec.id = "cmt"; sec.setAttribute("aria-labelledby", "cmt-h");
    var h = el("h2"); h.id = "cmt-h"; h.append("Bình luận ", el("span", "", ""));
    sec.append(h, el("div", "cmt-box-slot"), el("div", "cmt-list"));
    t.host.parentNode.insertBefore(sec, t.host);
    renderForm(); load();
  }
  function renderForm() {
    var slot = $("#cmt .cmt-box-slot"); if (!slot) return; slot.replaceChildren();
    var box = el("div", "cmt-box");
    if (!user) {
      box.append(el("p", "", "Đăng nhập hoặc tạo tài khoản miễn phí để chia sẻ cảm nhận, đặt câu hỏi hoặc kể trải nghiệm của bạn về Huế."));
      var row = el("div", "btns"), b1 = el("button", "btn", "Đăng nhập"), b2 = el("button", "btn ghost dk", "Tạo tài khoản");
      b1.type = b2.type = "button";
      b1.addEventListener("click", function () { openAuth("login"); }); b2.addEventListener("click", function () { openAuth("signup"); });
      row.append(b1, b2); box.append(row);
    } else {
      var f = el("form", "cmt-form"); f.noValidate = true;
      var lab = el("label", "f", "Bình luận với tên " + nameOf(user)), ta = el("textarea"); ta.maxLength = COMMENT_MAX; ta.rows = 4;
      ta.placeholder = "Viết bình luận của bạn…"; ta.setAttribute("aria-label", "Nội dung bình luận"); lab.append(ta);
      var row2 = el("div", "cmt-row"), cnt = el("span", "cmt-count", "0/" + COMMENT_MAX), go = el("button", "btn", "Đăng bình luận"); go.type = "submit";
      row2.append(cnt, go); var msg = el("div", "cmt-msg"); msg.setAttribute("role", "status"); msg.setAttribute("aria-live", "polite");
      f.append(lab, row2, msg); box.append(f);
      ta.addEventListener("input", function () { cnt.textContent = ta.value.length + "/" + COMMENT_MAX; });
      f.addEventListener("submit", async function (e) {
        e.preventDefault(); msg.replaceChildren();
        var v = ta.value.trim();
        if (v.length < 2) { msg.append(el("div", "msg", "Bình luận cần ít nhất 2 ký tự.")); ta.focus(); return; }
        var wait = COOLDOWN_MS - (Date.now() - lastPost);
        if (wait > 0) { msg.append(el("div", "msg", "Bạn gửi hơi nhanh. Hãy chờ " + Math.ceil(wait / 1000) + " giây rồi thử lại.")); return; }
        go.disabled = true; var old = go.textContent; go.textContent = "Đang gửi…";
        try {
          var r = await sb.from("comments").insert([{ page_key: mountedKey, content: v }]);
          if (r.error) throw r.error;
          lastPost = Date.now(); ta.value = ""; cnt.textContent = "0/" + COMMENT_MAX; toast("Đã đăng bình luận."); load();
        } catch (err) { console.error("Comment insert error:", err); msg.append(el("div", "msg", mapDbError(err))); }
        finally { go.disabled = false; go.textContent = old; }
      });
    }
    slot.append(box);
  }
  async function load() {
    var list = $("#cmt .cmt-list"), key = mountedKey; if (!list) return;
    list.replaceChildren(el("p", "cmt-empty", "Đang tải bình luận…"));
    try {
      var r = await sb.from("comments").select("id,user_id,display_name,content,created_at").eq("page_key", key).order("created_at", { ascending: false }).limit(PAGE_SIZE);
      if (r.error) throw r.error;
      if (key !== mountedKey || !$("#cmt")) return;
      var rows = r.data || [], n = $("#cmt h2 span"); if (n) n.textContent = rows.length ? "(" + rows.length + ")" : "";
      list.replaceChildren();
      if (!rows.length) { list.append(el("p", "cmt-empty", "Chưa có bình luận nào. Hãy là người đầu tiên chia sẻ cảm nhận.")); return; }
      rows.forEach(function (c) {
        var it = el("article", "cmt-item"), nm = c.display_name || "Thành viên";
        it.append(el("span", "cmt-av", nm.trim().charAt(0).toUpperCase() || "?"));
        var head = el("div", "cmt-head"), tm = el("time", "", fmtTime(c.created_at)); tm.dateTime = c.created_at;
        head.append(el("b", "", nm), tm); it.append(head);
        var body = el("div"); body.append(el("p", "cmt-body", c.content));
        if (user && c.user_id === user.id) {
          var del = el("button", "cmt-del", "Xóa bình luận của tôi"); del.type = "button";
          del.addEventListener("click", async function () {
            if (!confirm("Xóa bình luận này?")) return; del.disabled = true;
            var d = await sb.from("comments").delete().eq("id", c.id);
            if (d.error) { console.error(d.error); toast("Chưa xóa được bình luận."); del.disabled = false; } else { toast("Đã xóa bình luận."); load(); }
          });
          body.append(del);
        }
        it.append(body); list.append(it);
      });
    } catch (err) {
      console.error("Comment load error:", err);
      list.replaceChildren(el("p", "cmt-empty", mapDbError(err).indexOf("chưa được bật") > -1 ? mapDbError(err) : "Chưa tải được bình luận lúc này."));
    }
  }

  /* ---------- Khởi động ---------- */
  sb.auth.onAuthStateChange(function (ev, session) {
    user = session ? session.user : null;
    setTimeout(function () { renderAuthUI(); renderForm(); load(); prefillForms(); }, 0);
  });
  sb.auth.getSession().then(function (r) {
    user = r && r.data && r.data.session ? r.data.session.user : null;
    renderAuthUI(); renderForm(); prefillForms();
  }).catch(function (e) { console.warn("getSession:", e); renderAuthUI(); });
  window.addEventListener("hashchange", function () { setTimeout(function () { mount(); prefillForms(); }, 0); });
  renderAuthUI(); mount();
})();
