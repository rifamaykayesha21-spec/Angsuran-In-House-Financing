(async () => {
  if (!(await initPage())) return;

  const [{ data: kpi, error: e1 }, { data: top, error: e2 }, { data: aging, error: e3 }] = await Promise.all([
    db.from("v_dashboard_kpi").select("*").single(),
    db.from("v_contract_summary").select("*").eq("status", "active")
      .gt("days_overdue", 0).order("days_overdue", { ascending: false }).limit(5),
    db.from("v_aging_receivable").select("*"),
  ]);
  if (e1 || e2 || e3) return handleError(e1 || e2 || e3);

  const cards = [
    ["Pelanggan", num(kpi.total_customers)],
    ["Kontrak Aktif", num(kpi.active_contracts)],
    ["Total Piutang Berjalan", rupiah(kpi.total_outstanding)],
    ["Tunggakan", rupiah(kpi.total_overdue), "danger"],
    ["Kontrak Menunggak", num(kpi.overdue_contracts), "danger"],
    ["Tertagih Bulan Ini", rupiah(kpi.collected_this_month)],
    ["Pendapatan Bunga", rupiah(kpi.interest_income)],
  ];
  $("#kpis").innerHTML = cards.map(([l, v, c]) =>
    `<div class="card kpi ${c || ""}" style="margin:0"><div class="label">${l}</div><div class="value">${v}</div></div>`).join("");

  // Bar komposisi aging
  const sum = (k) => aging.reduce((s, r) => s + Number(r[k] || 0), 0);
  const buckets = [
    ["Belum jatuh tempo", sum("current_amt"), "#2f855a"],
    ["1-30 hari", sum("d1_30"), "#d69e2e"],
    ["31-60 hari", sum("d31_60"), "#dd6b20"],
    ["61-90 hari", sum("d61_90"), "#c05621"],
    ["> 90 hari", sum("d90_plus"), "#c0392b"],
  ];
  const total = buckets.reduce((s, b) => s + b[1], 0) || 1;
  $("#aging-bar").innerHTML =
    `<div class="bar">${buckets.map(([, v, c]) => `<span style="width:${(v / total) * 100}%;background:${c}"></span>`).join("")}</div>
     <div style="display:flex;gap:18px;flex-wrap:wrap;margin-top:10px">
       ${buckets.map(([l, v, c]) => `<div><span style="display:inline-block;width:10px;height:10px;background:${c};border-radius:2px"></span> ${l}: <b>${rupiah(v)}</b></div>`).join("")}
     </div>`;

  $("#overdue-body").innerHTML = top.length
    ? top.map((r) => `<tr><td>${esc(r.contract_no)}</td><td>${esc(r.customer_name)}</td>
        <td class="num">${r.days_overdue}</td><td class="num">${rupiah(r.overdue_amount)}</td>
        <td class="num">${rupiah(r.outstanding)}</td></tr>`).join("")
    : `<tr><td colspan="5" class="muted">Tidak ada tunggakan 🎉</td></tr>`;
})();
