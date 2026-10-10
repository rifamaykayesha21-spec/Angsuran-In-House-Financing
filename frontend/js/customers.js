(async () => {
  if (!(await initPage())) return;
  let all = [];

  async function load() {
    const { data, error } = await db.from("customers").select("*").order("created_at", { ascending: false });
    if (error) return handleError(error);
    all = data; render();
  }

  function render() {
    const q = $("#search").value.toLowerCase();
    const list = all.filter((c) => [c.full_name, c.nik, c.customer_code].join(" ").toLowerCase().includes(q));
    $("#rows").innerHTML = list.length ? list.map((c) => `
      <tr><td>${esc(c.customer_code)}</td><td>${esc(c.full_name)}</td><td>${esc(c.nik)}</td>
        <td>${esc(c.phone)}</td><td>${esc(c.occupation)}</td><td class="num">${rupiah(c.monthly_income)}</td>
        <td><button class="btn sm" data-edit="${c.customer_id}">Ubah</button>
            <button class="btn sm danger" data-del="${c.customer_id}">Hapus</button></td></tr>`).join("")
      : `<tr><td colspan="7" class="muted">Belum ada data</td></tr>`;
  }

  function openForm(c = {}) {
    $("#modal-title").textContent = c.customer_id ? "Ubah Pelanggan" : "Pelanggan Baru";
    for (const f of ["customer_id", "full_name", "nik", "phone", "occupation", "monthly_income", "address"])
      $("#" + f).value = c[f] ?? (f === "monthly_income" ? 0 : "");
    openModal("modal");
  }

  $("#btn-add").onclick = () => openForm();
  $("#btn-cancel").onclick = () => closeModal("modal");
  $("#search").oninput = render;

  $("#rows").onclick = async (e) => {
    const id = e.target.dataset.edit || e.target.dataset.del;
    if (!id) return;
    if (e.target.dataset.edit) return openForm(all.find((c) => c.customer_id === id));
    if (!confirm("Hapus pelanggan ini?")) return;
    const { error } = await db.from("customers").delete().eq("customer_id", id);
    if (error) return handleError(error, "Tidak bisa dihapus (mungkin sudah punya kontrak)");
    toast("Pelanggan dihapus"); load();
  };

  $("#form").onsubmit = async (e) => {
    e.preventDefault();
    const id = $("#customer_id").value;
    const payload = {
      full_name: $("#full_name").value.trim(), nik: $("#nik").value.trim(),
      phone: $("#phone").value.trim() || null, occupation: $("#occupation").value.trim() || null,
      monthly_income: Number($("#monthly_income").value || 0), address: $("#address").value.trim() || null,
    };
    const { error } = id
      ? await db.from("customers").update(payload).eq("customer_id", id)
      : await db.from("customers").insert(payload);
    if (error) return handleError(error);
    toast("Tersimpan"); closeModal("modal"); load();
  };

  load();
})();
