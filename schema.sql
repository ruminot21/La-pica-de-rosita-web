create extension if not exists pgcrypto;

create table if not exists public.customers (
 id uuid primary key default gen_random_uuid(),
 token uuid not null unique default gen_random_uuid(),
 full_name text not null check (char_length(full_name) between 2 and 100),
 phone text not null unique check (char_length(phone) between 7 and 22),
 stamps int not null default 0 check (stamps between 0 and 5),
 chosen_reward text check (chosen_reward in ('papas','bebida','hotdog')),
 reward_claimed boolean not null default false,
 cycles_completed int not null default 0,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.staff (user_id uuid primary key references auth.users(id) on delete cascade);
create table if not exists public.transactions (
 id bigint generated always as identity primary key,
 customer_id uuid not null references public.customers(id),
 staff_id uuid references auth.users(id),
 kind text not null check(kind in ('stamp','reward_choice','redeem')),
 reward text,
 created_at timestamptz not null default now()
);

alter table public.customers enable row level security;
alter table public.staff enable row level security;
alter table public.transactions enable row level security;
revoke all on public.customers from anon, authenticated;
revoke all on public.staff from anon, authenticated;
revoke all on public.transactions from anon, authenticated;

create or replace function public.is_staff() returns boolean language sql security definer set search_path = '' stable as $$
 select exists(select 1 from public.staff where user_id = auth.uid());
$$;

create or replace function public.register_customer(p_name text, p_phone text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c public.customers; clean_phone text;
begin
 clean_phone := regexp_replace(coalesce(p_phone,''), '[^0-9+]', '', 'g');
 if char_length(trim(coalesce(p_name,''))) < 2 or char_length(trim(p_name)) > 100 then raise exception 'Nombre inválido'; end if;
 if clean_phone !~ '^\+?[0-9]{7,15}$' then raise exception 'Teléfono inválido'; end if;
 -- No revelar tokens de registros existentes: si ya existe, pedir enlace original o ayuda en el local.
 if exists(select 1 from public.customers where phone=clean_phone) then raise exception 'Este teléfono ya está registrado. Solicita ayuda en el local para recuperar tu tarjeta.'; end if;
 insert into public.customers(full_name,phone) values(trim(p_name),clean_phone) returning * into c;
 return jsonb_build_object('token',c.token);
end $$;

create or replace function public.card_details(p_token uuid)
returns jsonb language plpgsql security definer set search_path = '' stable as $$
declare c public.customers;
begin
 select * into c from public.customers where token=p_token;
 if not found then return null; end if;
 return jsonb_build_object('name',c.full_name,'stamps',c.stamps,'reward',c.chosen_reward,'claimed',c.reward_claimed,'cycles',c.cycles_completed);
end $$;

create or replace function public.staff_lookup(p_token uuid)
returns jsonb language plpgsql security definer set search_path = '' stable as $$
declare c public.customers;
begin
 if not public.is_staff() then raise exception 'Acceso denegado'; end if;
 select * into c from public.customers where token=p_token;
 if not found then raise exception 'Tarjeta no encontrada'; end if;
 return jsonb_build_object('token',c.token,'name',c.full_name,'phone',c.phone,'stamps',c.stamps,'reward',c.chosen_reward,'claimed',c.reward_claimed,'cycles',c.cycles_completed);
end $$;

create or replace function public.add_stamp(p_token uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c public.customers;
begin
 if not public.is_staff() then raise exception 'Acceso denegado'; end if;
 select * into c from public.customers where token=p_token for update;
 if not found then raise exception 'Tarjeta no encontrada'; end if;
 if c.stamps >= 5 then raise exception 'Ya completó 5 sellos: debe elegir y canjear su premio'; end if;
 update public.customers set stamps=stamps+1,updated_at=now() where id=c.id;
 insert into public.transactions(customer_id,staff_id,kind) values(c.id,auth.uid(),'stamp');
 return public.staff_lookup(p_token);
end $$;

create or replace function public.choose_reward(p_token uuid, p_reward text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c public.customers;
begin
 if p_reward not in ('papas','bebida','hotdog') then raise exception 'Premio inválido'; end if;
 select * into c from public.customers where token=p_token for update;
 if not found then raise exception 'Tarjeta no encontrada'; end if;
 if c.stamps != 5 or c.reward_claimed then raise exception 'Todavía no puede elegir un premio'; end if;
 update public.customers set chosen_reward=p_reward,updated_at=now() where id=c.id;
 insert into public.transactions(customer_id,staff_id,kind,reward) values(c.id,null,'reward_choice',p_reward);
 return public.card_details(p_token);
end $$;

create or replace function public.redeem_reward(p_token uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c public.customers;
begin
 if not public.is_staff() then raise exception 'Acceso denegado'; end if;
 select * into c from public.customers where token=p_token for update;
 if not found then raise exception 'Tarjeta no encontrada'; end if;
 if c.stamps != 5 or c.chosen_reward is null then raise exception 'El cliente debe completar los sellos y elegir premio'; end if;
 insert into public.transactions(customer_id,staff_id,kind,reward) values(c.id,auth.uid(),'redeem',c.chosen_reward);
 update public.customers set stamps=0,chosen_reward=null,reward_claimed=false,cycles_completed=cycles_completed+1,updated_at=now() where id=c.id;
 return public.staff_lookup(p_token);
end $$;

grant execute on function public.register_customer(text,text) to anon,authenticated;
grant execute on function public.card_details(uuid) to anon,authenticated;
grant execute on function public.choose_reward(uuid,text) to anon,authenticated;
grant execute on function public.is_staff() to authenticated;
grant execute on function public.staff_lookup(uuid) to authenticated;
grant execute on function public.add_stamp(uuid) to authenticated;
grant execute on function public.redeem_reward(uuid) to authenticated;
