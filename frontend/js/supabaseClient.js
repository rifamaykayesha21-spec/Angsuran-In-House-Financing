// Membuat satu client Supabase yang dipakai semua halaman.
// Library `supabase` dimuat dari CDN pada setiap file HTML.
const db = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
