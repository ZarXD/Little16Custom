const SILEO_URL = "sileo://source/https://zarxd.github.io/Little16Custom";
const REPO_URL = "https://zarxd.github.io/Little16Custom";

function toast(msg) {
  let t = document.getElementById("toast");
  if (!t) {
    t = document.createElement("div");
    t.id = "toast";
    t.className = "toast";
    document.body.appendChild(t);
  }
  t.textContent = msg;
  t.classList.add("show");
  clearTimeout(t._tm);
  t._tm = setTimeout(() => t.classList.remove("show"), 2400);
}

function copyText(text, okMsg) {
  const done = () => toast(okMsg);
  if (navigator.clipboard && window.isSecureContext) {
    navigator.clipboard.writeText(text).then(done).catch(() => fallbackCopy(text, done));
  } else {
    fallbackCopy(text, done);
  }
}

function fallbackCopy(text, done) {
  const ta = document.createElement("textarea");
  ta.value = text;
  ta.style.position = "fixed";
  ta.style.opacity = "0";
  document.body.appendChild(ta);
  ta.select();
  try { document.execCommand("copy"); } catch (e) {}
  document.body.removeChild(ta);
  done();
}

document.addEventListener("DOMContentLoaded", () => {
  document.getElementById("copyBtn")?.addEventListener("click", () => {
    copyText(REPO_URL, "URL repo tersalin ke clipboard");
  });
  document.getElementById("addSileo")?.addEventListener("click", (e) => {
    if (/Cydget|Sileo|Zebra|Cydia/i.test(navigator.userAgent)) {
      window.location.href = SILEO_URL;
    } else {
      copyText(SILEO_URL, "Tambahkan repo ini di Sileo manual — URL ada di kartu repo di bawah");
    }
  });

  document.querySelectorAll("[data-sileo]").forEach((el) => {
    el.addEventListener("click", () => copyText(SILEO_URL, "URL Sileo tersalin ke clipboard"));
  });
});