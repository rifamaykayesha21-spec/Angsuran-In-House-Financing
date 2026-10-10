// Sidebar. Panggil: await initPage()  (mode tanpa login)
const NAV = [
  ["index.html", "Dashboard"],
  ["customers.html", "Pelanggan"],
  ["products.html", "Produk"],
  ["contracts.html", "Kontrak Piutang"],
  ["payments.html", "Pembayaran Angsuran"],
  ["reports.html", "Laporan"],
];

async function initPage() {
  const current = location.pathname.split("/").pop() || "index.html";
  $("#app-nav").innerHTML = `
    <h1>IHF Piutang<small>Piutang &amp; Angsuran</small></h1>
    ${NAV.map(([href, label]) =>
      `<a href="${href}" class="${href === current ? "active" : ""}">${label}</a>`).join("")}`;
  return true;
}
