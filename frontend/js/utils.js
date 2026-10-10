// Fungsi bantu yang dipakai bersama
const rupiah = (n) =>
  "Rp " + Number(n || 0).toLocaleString("id-ID", { maximumFractionDigits: 0 });
const num = (n) => Number(n || 0).toLocaleString("id-ID", { maximumFractionDigits: 0 });

const fmtDate = (d) =>
  d ? new Date(d + (String(d).length === 10 ? "T00:00:00" : "")).toLocaleDateString("id-ID",
        { day: "2-digit", month: "short", year: "numeric" }) : "-";

const today = () => new Date().toISOString().slice(0, 10);

// Hindari XSS saat menyisipkan teks dari database ke innerHTML
const esc = (s) =>
  String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

const $ = (sel, root = document) => root.querySelector(sel);

function toast(msg, type = "success") {
  let box = $("#toast");
  if (!box) { box = document.createElement("div"); box.id = "toast"; document.body.appendChild(box); }
  const el = document.createElement("div");
  el.className = type; el.textContent = msg;
  box.appendChild(el);
  setTimeout(() => el.remove(), 4000);
}

const openModal  = (id) => $("#" + id).classList.add("open");
const closeModal = (id) => $("#" + id).classList.remove("open");

function statusBadge(status) {
  const map = {
    active: ["Aktif", "ok"], paid_off: ["Lunas", ""], written_off: ["Hapus Buku", "bad"],
    unpaid: ["Belum bayar", "warn"], partial: ["Sebagian", "warn"], paid: ["Lunas", "ok"],
  };
  const [label, cls] = map[status] || [status, ""];
  return `<span class="badge ${cls}">${label}</span>`;
}

// Tampilkan error Supabase dengan ramah
function handleError(error, fallback = "Terjadi kesalahan") {
  console.error(error);
  toast(error?.message || fallback, "error");
}
