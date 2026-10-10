(async () => {
  if (!(await initPage())) return;
  let all = [];

  async function load() {
    const { data, error } = await db.from("products").select("*").order("product_code");
    if (error) return handleError(error);
    all = data;
    $("#rows").innerHTML = all.length ? all.map((p) => `
      <tr><td>${esc(p.product_code)}</td><td>${esc(p.product_name)}</td>
        <td class="num">${rupiah(p.cost_price)}</td><td class="num">${rupiah(p.cash_price)}</td>
        <td>${p.is_active ? '<span class="badge ok">Aktif</span>' : '<span class="badge">Nonaktif</span>'}</td>
        <td><button class="btn sm" data-edit="${p.product_id}">Ubah</button>
            <button class="btn sm danger" data-del="${p.product_id}">Hapus</button></td></tr>`).join("")
      : `<tr><td colspan="6" class="muted">Belum ada data</td></tr>`;
  }

  function openForm(p = {}) {
    $("#modal-title").textContent = p.product_id ? "Ubah Produk" : "Produk Baru";
    $("#product_id").value = p.product_id ?? "";
    $("#product_name").value = p.product_name ?? "";
    $("#cost_price").value = p.cost_price ?? "";
    $("#cash_price").value = p.cash_price ?? "";
    $("#is_active").value = String(p.is_active ?? true);
    openModal("modal");
  }

  $("#btn-add").onclick = () => openForm();
  $("#btn-cancel").onclick = () => closeModal("modal");

  $("#rows").onclick = async (e) => {
    if (e.target.dataset.edit) return openForm(all.find((p) => p.product_id === e.target.dataset.edit));
    if (e.target.dataset.del) {
      if (!confirm("Hapus produk ini?")) return;
      const { error } = await db.from("products").delete().eq("product_id", e.target.dataset.del);
      if (error) return handleError(error, "Tidak bisa dihapus (sudah dipakai kontrak). Nonaktifkan saja.");
      toast("Produk dihapus"); load();
    }
  };

  $("#form").onsubmit = async (e) => {
    e.preventDefault();
    const id = $("#product_id").value;
    const payload = {
      product_name: $("#product_name").value.trim(),
      cost_price: Number($("#cost_price").value), cash_price: Number($("#cash_price").value),
      is_active: $("#is_active").value === "true",
    };
    const { error } = id
      ? await db.from("products").update(payload).eq("product_id", id)
      : await db.from("products").insert(payload);
    if (error) return handleError(error);
    toast("Tersimpan"); closeModal("modal"); load();
  };

  load();
})();
