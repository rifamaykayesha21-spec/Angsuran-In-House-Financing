(async () => {
  if (!(await initPage())) return;

  const thead = (cols) => `<thead><tr>${cols.map((c) => `<th${c.startsWith("#") ? ' class="num"' : ""}>${c.replace("#", "")}</th>`).join("")}</tr></thead>`;

  const reports = {
    async aging() {
      const { data, error } = await db.from("v_aging_receivable").select("*").order("contract_no");
      if (error) throw error;
      const t = (k) => data.reduce((s, r) => s + Number(r[k] || 0), 0);
      return `<h3>Umur Piutang (Aging Schedule)</h3><div class="table-wrap"><table>
        ${thead(["Kontrak", "Pelanggan", "#Belum JT", "#1-30 hr", "#31-60 hr", "#61-90 hr", "#> 90 hr", "#Total"])}
        <tbody>${data.map((r) => `<tr><td>${esc(r.contract_no)}</td><td>${esc(r.customer_name)}</td>
          ${["current_amt", "d1_30", "d31_60", "d61_90", "d90_plus", "total_outstanding"].map((k) => `<td class="num">${num(r[k])}</td>`).join("")}</tr>`).join("")
          || '<tr><td colspan="8" class="muted">Tidak ada data</td></tr>'}</tbody>
        <tfoot><tr><td colspan="2">Total</td>${["current_amt", "d1_30", "d31_60", "d61_90", "d90_plus", "total_outstanding"].map((k) => `<td class="num">${num(t(k))}</td>`).join("")}</tr></tfoot>
      </table></div>`;
    },

    async tb() {
      const { data, error } = await db.from("v_trial_balance").select("*").order("account_code");
      if (error) throw error;
      const d = data.reduce((s, r) => s + Number(r.total_debit), 0), c = data.reduce((s, r) => s + Number(r.total_credit), 0);
      return `<h3>Neraca Saldo</h3><div class="table-wrap"><table>
        ${thead(["Kode", "Akun", "Tipe", "#Debit", "#Kredit", "#Saldo"])}
        <tbody>${data.map((r) => `<tr><td>${esc(r.account_code)}</td><td>${esc(r.account_name)}</td><td>${esc(r.account_type)}</td>
          <td class="num">${num(r.total_debit)}</td><td class="num">${num(r.total_credit)}</td><td class="num">${num(r.balance)}</td></tr>`).join("")}</tbody>
        <tfoot><tr><td colspan="3">Total ${d === c ? "✔ balance" : "✖ TIDAK balance"}</td><td class="num">${num(d)}</td><td class="num">${num(c)}</td><td></td></tr></tfoot>
      </table></div>`;
    },

    async gl() {
      const { data, error } = await db.from("v_general_ledger").select("*")
        .order("journal_date", { ascending: false }).order("journal_no", { ascending: false }).limit(300);
      if (error) throw error;
      return `<h3>Jurnal / Buku Besar (300 baris terakhir)</h3><div class="table-wrap"><table>
        ${thead(["Tanggal", "No. Jurnal", "Keterangan", "Akun", "#Debit", "#Kredit"])}
        <tbody>${data.map((r) => `<tr><td>${fmtDate(r.journal_date)}</td><td>${esc(r.journal_no)}</td><td>${esc(r.description)}</td>
          <td>${esc(r.account_code)} ${esc(r.account_name)}</td>
          <td class="num">${r.debit > 0 ? num(r.debit) : ""}</td><td class="num">${r.credit > 0 ? num(r.credit) : ""}</td></tr>`).join("")}</tbody>
      </table></div>`;
    },
  };

  async function show(name) {
    document.querySelectorAll("#tabs button").forEach((b) => b.classList.toggle("active", b.dataset.tab === name));
    $("#report").innerHTML = '<span class="muted">Memuat...</span>';
    try { $("#report").innerHTML = await reports[name](); } catch (e) { handleError(e); }
  }

  $("#tabs").onclick = (e) => e.target.dataset.tab && show(e.target.dataset.tab);
  show("aging");
})();
