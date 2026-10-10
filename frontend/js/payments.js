(async () => {
  if (!(await initPage())) return;
  let contracts = [];
  $("#payment_date").value = today();

  async function loadContracts() {
    const { data, error } = await db.from("v_contract_summary").select("*").eq("status", "active").order("contract_no");
    if (error) return handleError(error);
    contracts = data;
    $("#contract_id").innerHTML = `<option value="">-- pilih kontrak --</option>` + data.map((c) =>
      `<option value="${c.contract_id}">${esc(c.contract_no)} - ${esc(c.customer_name)} (sisa ${rupiah(c.outstanding)})</option>`).join("");
  }

  async function showInfo() {
    const id = $("#contract_id").value;
    const c = contracts.find((x) => x.contract_id === id);
    if (!c) { $("#contract-info").textContent = "Pilih kontrak untuk melihat tagihan."; return; }
    const { data: next } = await db.from("installments").select("*").eq("contract_id", id)
      .neq("status", "paid").order("installment_no").limit(1).single();
    const sisaNext = next ? Number(next.amount_due) - Number(next.principal_paid) - Number(next.interest_paid) : 0;
    $("#contract-info").innerHTML = `
      Sisa piutang: <b>${rupiah(c.outstanding)}</b> · Tunggakan: <b>${rupiah(c.overdue_amount)}</b>
      ${c.days_overdue > 0 ? `<span class="badge bad">telat ${c.days_overdue} hari</span>` : ""}<br>
      Angsuran berikutnya: ke-<b>${next?.installment_no ?? "-"}</b>, jatuh tempo <b>${fmtDate(next?.due_date)}</b>, sisa tagihan <b>${rupiah(sisaNext)}</b><br>
      <span class="muted">Alokasi otomatis: denda → bunga → pokok, ke angsuran tertua. Denda dihitung oleh sistem saat disimpan.</span>`;
    if (!$("#amount").value) $("#amount").value = sisaNext;
  }
  $("#contract_id").onchange = () => { $("#amount").value = ""; showInfo(); };

  async function loadHistory() {
    const { data, error } = await db.from("payments")
      .select("*, contracts(contract_no, customers(full_name))")
      .order("created_at", { ascending: false }).limit(50);
    if (error) return handleError(error);
    $("#rows").innerHTML = data.length ? data.map((p) => `
      <tr><td>${esc(p.receipt_no)}</td><td>${fmtDate(p.payment_date)}</td>
        <td>${esc(p.contracts?.contract_no)}</td><td>${esc(p.contracts?.customers?.full_name)}</td>
        <td>${esc(p.method)}</td><td class="num">${rupiah(p.penalty_amount)}</td><td class="num">${rupiah(p.amount)}</td></tr>`).join("")
      : `<tr><td colspan="7" class="muted">Belum ada pembayaran</td></tr>`;
  }

  $("#form").onsubmit = async (e) => {
    e.preventDefault();
    const btn = $("#btn-save"); btn.disabled = true;
    const { error } = await db.rpc("process_payment", {
      p_contract_id: $("#contract_id").value,
      p_payment_date: $("#payment_date").value,
      p_amount: Number($("#amount").value),
      p_method: $("#method").value,
      p_notes: $("#notes").value.trim() || null,
    });
    btn.disabled = false;
    if (error) return handleError(error);
    toast("Pembayaran tercatat & jurnal terbentuk");
    $("#amount").value = ""; $("#notes").value = "";
    await loadContracts(); showInfo(); loadHistory();
  };

  await loadContracts();
  loadHistory();
})();
