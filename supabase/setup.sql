-- =========================================================
-- Safary 2000 — database setup (run once in Supabase → SQL Editor)
-- =========================================================

-- Who may edit the menu (add the admin's login email below)
create table if not exists public.admins (
  email text primary key
);
insert into public.admins (email) values ('ADMIN_EMAIL_HERE') on conflict do nothing;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where lower(email) = lower(auth.jwt() ->> 'email'));
$$;

-- Menu categories
create table if not exists public.categories (
  id text primary key,
  name_en text not null,
  name_ar text not null default '',
  color text not null default '#B8640F',
  sort integer not null default 0,
  visible boolean not null default true
);

-- Dishes
create table if not exists public.items (
  id text primary key default gen_random_uuid()::text,
  category_id text not null references public.categories(id) on update cascade on delete cascade,
  name_en text not null,
  name_ar text not null default '',
  desc_en text not null default '',
  desc_ar text not null default '',
  price integer not null default 0 check (price >= 0),
  tags text[] not null default '{}',
  photo text not null default '',
  sort integer not null default 0,
  visible boolean not null default true,
  updated_at timestamptz not null default now()
);

create or replace function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
drop trigger if exists items_touch on public.items;
create trigger items_touch before update on public.items for each row execute function public.touch_updated_at();

-- Row level security: everyone can read visible rows, only admins can change anything
alter table public.admins enable row level security;
alter table public.categories enable row level security;
alter table public.items enable row level security;

drop policy if exists "read visible categories" on public.categories;
create policy "read visible categories" on public.categories for select using (visible or public.is_admin());
drop policy if exists "admins manage categories" on public.categories;
create policy "admins manage categories" on public.categories for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "read visible items" on public.items;
create policy "read visible items" on public.items for select using (visible or public.is_admin());
drop policy if exists "admins manage items" on public.items;
create policy "admins manage items" on public.items for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admins read admins" on public.admins;
create policy "admins read admins" on public.admins for select to authenticated using (public.is_admin());

-- Dish photos: public to view, only admins can upload or delete
insert into storage.buckets (id, name, public) values ('menu', 'menu', true) on conflict (id) do nothing;
drop policy if exists "menu photos public read" on storage.objects;
create policy "menu photos public read" on storage.objects for select using (bucket_id = 'menu');
drop policy if exists "admins upload menu photos" on storage.objects;
create policy "admins upload menu photos" on storage.objects for insert to authenticated with check (bucket_id = 'menu' and public.is_admin());
drop policy if exists "admins update menu photos" on storage.objects;
create policy "admins update menu photos" on storage.objects for update to authenticated using (bucket_id = 'menu' and public.is_admin());
drop policy if exists "admins delete menu photos" on storage.objects;
create policy "admins delete menu photos" on storage.objects for delete to authenticated using (bucket_id = 'menu' and public.is_admin());
