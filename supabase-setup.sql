-- Execute no SQL Editor do Supabase depois de criar o usuário em Authentication > Users.
-- Substitua ADMIN_EMAIL_AQUI pelo e-mail da administradora, sem divulgar a senha.
create extension if not exists pgcrypto;
create table if not exists public.admin_users (
 user_id uuid primary key references auth.users(id) on delete cascade
);
create table if not exists public.products (
 id uuid primary key default gen_random_uuid(),
 name text not null, description text not null default '',
 price numeric(12,2) not null check(price>=0),
 old_price numeric(12,2) check(old_price>=0),
 category text not null check(category in ('Roupas','Moda íntima','Conjuntos')),
 fabric text not null default '', sizes text[] not null default '{}',
 colors text[] not null default '{}', stock integer not null default 0 check(stock>=0),
 tag text not null default '', image_url text, active boolean not null default true,
 created_at timestamptz not null default now()
);
alter table public.admin_users enable row level security;
alter table public.products enable row level security;
-- Função protegida para verificar administradora sem expor tabela de permissões.
create or replace function public.is_monaly_admin() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.admin_users where user_id=(select auth.uid()));
$$;
revoke all on function public.is_monaly_admin() from public;
grant execute on function public.is_monaly_admin() to authenticated, anon;
drop policy if exists "admin self read" on public.admin_users;
create policy "admin self read" on public.admin_users for select to authenticated using(user_id=(select auth.uid()));
drop policy if exists "public active products" on public.products;
create policy "public active products" on public.products for select to anon,authenticated using(active=true or (select public.is_monaly_admin()));
drop policy if exists "admin insert products" on public.products;
create policy "admin insert products" on public.products for insert to authenticated with check((select public.is_monaly_admin()));
drop policy if exists "admin update products" on public.products;
create policy "admin update products" on public.products for update to authenticated using((select public.is_monaly_admin())) with check((select public.is_monaly_admin()));
drop policy if exists "admin delete products" on public.products;
create policy "admin delete products" on public.products for delete to authenticated using((select public.is_monaly_admin()));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('product-images','product-images',true,5242880,array['image/jpeg','image/png','image/webp'])
 on conflict(id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
drop policy if exists "admin upload product images" on storage.objects;
create policy "admin upload product images" on storage.objects for insert to authenticated with check(bucket_id='product-images' and (select public.is_monaly_admin()));
drop policy if exists "admin update product images" on storage.objects;
create policy "admin update product images" on storage.objects for update to authenticated using(bucket_id='product-images' and (select public.is_monaly_admin()));
drop policy if exists "admin delete product images" on storage.objects;
create policy "admin delete product images" on storage.objects for delete to authenticated using(bucket_id='product-images' and (select public.is_monaly_admin()));
-- ATENÇÃO: troque o e-mail abaixo antes de executar. Crie primeiro o usuário em Authentication > Users.
insert into public.admin_users(user_id)
select id from auth.users where lower(email)=lower('ADMIN_EMAIL_AQUI')
on conflict(user_id) do nothing;
