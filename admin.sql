-- Ejecutar DESPUÉS de schema.sql. Panel privado: solo usuarios de public.staff.
create table if not exists public.business_settings (id integer primary key default 1 check(id=1), business_name text not null default 'La Pica de Rosita', logo_url text default '', tagline text not null default '¡El sabor que siempre te hace volver!');
insert into public.business_settings(id) values (1) on conflict do nothing;
alter table public.business_settings enable row level security;
revoke all on public.business_settings from anon, authenticated;
create or replace function public.get_business_settings() returns jsonb language sql security definer set search_path='' stable as $$ select jsonb_build_object('name',business_name,'logo',logo_url,'tagline',tagline) from public.business_settings where id=1 $$;
create or replace function public.admin_save_settings(p_name text,p_logo text,p_tagline text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.is_staff() then raise exception 'Acceso denegado'; end if;
 if length(trim(coalesce(p_name,''))) not between 2 and 90 then raise exception 'Nombre inválido'; end if;
 if length(coalesce(p_logo,''))>1000 or (nullif(trim(coalesce(p_logo,'')),'') is not null and p_logo !~ '^https://') then raise exception 'Logo: usa una URL https válida'; end if;
 update public.business_settings set business_name=trim(p_name),logo_url=trim(coalesce(p_logo,'')),tagline=left(coalesce(p_tagline,''),150) where id=1;
end $$;
create or replace function public.admin_overview() returns jsonb language plpgsql security definer set search_path='' stable as $$
begin
 if not public.is_staff() then raise exception 'Acceso denegado'; end if;
 return jsonb_build_object('customers',(select count(*) from public.customers),'stamps',(select count(*) from public.transactions where kind='stamp'),'redemptions',(select count(*) from public.transactions where kind='redeem'));
end $$;
create or replace function public.admin_customers() returns jsonb language plpgsql security definer set search_path='' stable as $$
begin
 if not public.is_staff() then raise exception 'Acceso denegado'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('name',full_name,'phone',phone,'token',token,'stamps',stamps,'reward',chosen_reward,'cycles',cycles_completed,'created_at',created_at) order by created_at desc) from public.customers),'[]'::jsonb);
end $$;
create or replace function public.admin_transactions() returns jsonb language plpgsql security definer set search_path='' stable as $$
begin
 if not public.is_staff() then raise exception 'Acceso denegado'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('customer',c.full_name,'kind',t.kind,'reward',t.reward,'date',t.created_at,'staff',t.staff_id) order by t.created_at desc) from (select * from public.transactions order by created_at desc limit 500) t join public.customers c on c.id=t.customer_id),'[]'::jsonb);
end $$;
grant execute on function public.get_business_settings() to anon,authenticated;
grant execute on function public.admin_save_settings(text,text,text) to authenticated;
grant execute on function public.admin_overview() to authenticated;
grant execute on function public.admin_customers() to authenticated;
grant execute on function public.admin_transactions() to authenticated;
