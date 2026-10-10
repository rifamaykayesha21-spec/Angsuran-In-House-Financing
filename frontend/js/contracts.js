(async () => {
  if (!(await initPage())) return;
  let products = [];

  async function load() {
    const { data, error } = await db.from("v_contract_summary").select("*").order("contract_date", { ascending: false });
    if (error) return handleError(error);
    $("#rows").innerHTML = data.length ? data.map((c) => `
      <tr><td>${esc(c.contract_no)}</td><td>${fmtDate(c.contract_date)}</td><td>${esc(c.customer_name)}</td>
        <td>${esc(c.product_name)}</td><td class="num">${rupiah(c.total_receivable)}</td>
        <td class="num">${rupiah(c.total_paid)}</td><td class="num">${rupiah(c.outstanding)}</td>
        <td>${statusBadge(c.status)}${c.days_overdue > 0 ? ` <span class="badge bad">telat ${c.days_overdue} hr</span>` : ""}</td>
        <td><button class="btn sm" data-detail="${c.contract_id}" data-no="${esc(c.contract_no)}">Jadwal</button></td></tr>`).join("")
      : `<tr><td colspan="9" class="muted">Belum ada kontrak</td></tr>`;
  }

  async function loadOptions() {
    const [c, p] = await Promise.all([
      db.from("customers").select("customer_id, customer_code, full_name").order("full_name"),
      db.from("products").select("*").eq("is_active", true).order("product_name"),
    ]);
    if (c.error || p.error) return handleError(c.error || p.error);
    products = p.data;
    $("#customer_id").innerHTML = c.data.map((x) => `<option value="${x.customer_id}">${esc(x.customer_code)} - ${esc(x.full_name)}</option>`).join("");
    $("#product_id").innerHTML = p.data.map((x) => `<option value="${x.product_id}">${esc(x.product_name)} (${rupiah(x.cash_price)})</option>`).join("");
  }

  // Simulasi (rumus sama dengan fungsi SQL create_contract)
  function simulate() {
    const p = products.find((x) => x.product_id === $("#product_id").value);
    if (!p) return;
    const dp = Number($("#down_payment").value || 0), rate = Number($("#annual_rate").value || 0);
    const tenor = Number($("#tenor").value || 1);
    const fin = p.cash_price - dp, interest = Math.round(fin * rate / 100 * tenor / 12), total = fin + interest;
    $("#simulation").innerHTML = dp >= p.cash_price
      ? "⚠ Uang muka harus lebih kecil dari harga tunai."
      : `Harga tunai: <b>${rupiah(p.cash_price)}</b> · Pokok pembiayaan: <b>${rupiah(fin)}</b><br>
         Total bunga: <b>${rupiah(interest)}</b> · Total piutang: <b>${rupiah(total)}</b><br>
         Angsuran per bulan: <b>${rupiah(Math.round(total / tenor))}</b> × ${tenor} bulan`;
  }
  ["product_id", "down_payment", "annual_rate", "tenor"].forEach((id) => $("#" + id).addEventListener("input", simulate));

  $("#btn-add").onclick = async () => {
    await loadOptions();
    $("#contract_date").value = today();
    simulate(); openModal("modal");
  };
  $("#btn-cancel").onclick = () => closeModal("modal");

  $("#form").onsubmit = async (e) => {
    e.preventDefault();
    const btn = $("#btn-save"); btn.disabled = true;
    const { error } = await db.rpc("create_contract", {
      p_customer_id: $("#customer_id").value,
      p_product_id: $("#product_id").value,
      p_contract_date: $("#contract_date").value,
      p_down_payment: Number($("#down_payment").value),
      p_annual_rate: Number($("#annual_rate").value),
      p_tenor: Number($("#tenor").value),
      p_late_fee_rate: Number($("#late_fee_rate").value),
    });
    btn.disabled = false;
    if (error) return handleError(error);
    toast("Kontrak dibuat, jadwal & jurnal otomatis terbentuk");
    closeModal("modal"); load();
  };

  // Detail jadwal angsuran
  $("#rows").onclick = async (e) => {
    const id = e.target.dataset.detail;
    if (!id) return;
    const { data, error } = await db.from("installments").select("*").eq("contract_id", id).order("installment_no");
    if (error) return handleError(error);
    $("#detail-title").textContent = "Jadwal Angsuran " + e.target.dataset.no;
    $("#detail-rows").innerHTML = data.map((i) => `
      <tr><td>${i.installment_no}</td><td>${fmtDate(i.due_date)}</td>
        <td class="num">${rupiah(i.principal_amount)}</td><td class="num">${rupiah(i.interest_amount)}</td>
        <td class="num">${rupiah(i.amount_due)}</td><td class="num">${rupiah(Number(i.principal_paid) + Number(i.interest_paid))}</td>
        <td>${statusBadge(i.status)}${i.status !== "paid" && i.due_date < today() ? ' <span class="badge bad">jatuh tempo</span>' : ""}</td></tr>`).join("");
    openModal("modal-detail");
  };
  $("#btn-close-detail").onclick = () => closeModal("modal-detail");

  load();
})();
