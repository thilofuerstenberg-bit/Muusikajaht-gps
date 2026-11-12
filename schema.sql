-- Run in Supabase SQL Editor. Enable Anonymous Sign-ins in Authentication > Providers.
create extension if not exists pgcrypto;
create table if not exists public.teachers (user_id uuid primary key references auth.users(id) on delete cascade);
create or replace function public.is_teacher() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.teachers where user_id=auth.uid()); $$;
revoke all on function public.is_teacher() from public;
grant execute on function public.is_teacher() to authenticated;
create table if not exists public.stations (id integer primary key check(id between 1 and 12), title text not null, question text not null, kind text not null check(kind in ('quiz','creative')), options jsonb, correct integer, latitude double precision, longitude double precision, radius integer not null default 30 check(radius between 15 and 150));
create table if not exists public.teams (id uuid primary key default gen_random_uuid(), owner uuid not null unique references auth.users(id), name text not null check(length(name) between 2 and 60), created_at timestamptz default now());
create table if not exists public.submissions (id uuid primary key default gen_random_uuid(), owner uuid not null references auth.users(id), station_id integer not null references public.stations(id), answer text not null default '', media_path text, score integer not null default 0 check(score between 0 and 3), reviewed boolean not null default false, created_at timestamptz default now(), unique(owner,station_id));
create index if not exists submissions_owner_idx on public.submissions(owner);
alter table public.teachers enable row level security;
alter table public.stations enable row level security;
alter table public.teams enable row level security;
alter table public.submissions enable row level security;
create policy "teacher self read" on public.teachers for select to authenticated using(user_id=auth.uid());
create policy "stations public read" on public.stations for select to authenticated using(true);
create policy "stations teacher insert" on public.stations for insert to authenticated with check(public.is_teacher());
create policy "stations teacher update" on public.stations for update to authenticated using(public.is_teacher()) with check(public.is_teacher());
create policy "teams owner insert" on public.teams for insert to authenticated with check(owner=auth.uid());
create policy "teams owner read or teacher" on public.teams for select to authenticated using(owner=auth.uid() or public.is_teacher());
create policy "submissions owner insert" on public.submissions for insert to authenticated with check(owner=auth.uid() and score=0 and reviewed=false and media_path is null);
create policy "submissions read" on public.submissions for select to authenticated using(owner=auth.uid() or public.is_teacher());
create policy "submissions teacher review" on public.submissions for update to authenticated using(public.is_teacher()) with check(public.is_teacher());
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('music-evidence','music-evidence',false,20971520,array['image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime']) on conflict(id) do update set public=false,file_size_limit=20971520,allowed_mime_types=excluded.allowed_mime_types;
create policy "students upload own evidence" on storage.objects for insert to authenticated with check(bucket_id='music-evidence' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "students and teachers read evidence" on storage.objects for select to authenticated using(bucket_id='music-evidence' and ((storage.foldername(name))[1]=auth.uid()::text or public.is_teacher()));
insert into public.stations(id,title,question,kind,options,correct) values
(1,'Rütmimeistrid','Plaksutage TA TA TI-TI TA ja filmige oma uus rütm.','creative',null,null),
(2,'Noodidetektiiv','Mitu joont on noodijoonestikul?','quiz','["4","5","6"]',1),
(3,'Pillide saladus','Milline neist on keelpill?','quiz','["Trompet","Viiul","Flööt"]',1),
(4,'Laululahing','Salvestage lühike eestikeelne laul (ilma teiste õpilaste nägudeta).','creative',null,null),
(5,'Helide jaht','Leidke huvitav heli ja pildistage selle allikas.','creative',null,null),
(6,'Helilooja','Kes neist on Eesti helilooja?','quiz','["Arvo Pärt","Ott Tänak","Kristjan Ilves"]',0),
(7,'Tempo','Mida tähendab allegro?','quiz','["Aeglaselt","Kiiresti","Vaikselt"]',1),
(8,'Inimorkester','Filmige 10-sekundiline keharütmi esitus.','creative',null,null),
(9,'Rahvapillid','Milline neist on eesti rahvapill?','quiz','["Kannel","Saksofon","Tromboon"]',0),
(10,'Noodimatemaatika','Mitu kaheksandiknooti on täisnoodis?','quiz','["4","8","16"]',1),
(11,'Ehita pill','Looge ohututest maas leiduvatest materjalidest heli tekitav ese ja pildistage.','creative',null,null),
(12,'Muusikaline maakunst','Tehke langenud lehtedest või okstest suur noodimärk ja pildistage.','creative',null,null)
on conflict(id) do nothing;
-- AFTER teacher has signed up with email OTP, run this replacing the address:
-- insert into public.teachers(user_id) select id from auth.users where email='TEACHER_EMAIL_HERE' on conflict do nothing;
create or replace function public.grade_submission() returns trigger language plpgsql security definer set search_path=public as $$
declare s public.stations%rowtype;
begin
 select * into s from public.stations where id=new.station_id;
 if new.owner <> auth.uid() then raise exception 'Invalid owner'; end if;
 if s.latitude is null then raise exception 'Station not placed'; end if;
 if s.kind='quiz' then
   if new.answer !~ '^[0-9]+$' or new.answer::integer < 0 or new.answer::integer >= jsonb_array_length(s.options) then raise exception 'Invalid answer'; end if;
   new.score:=case when new.answer::integer=s.correct then 1 else 0 end;
 else new.score:=0; end if;
 new.reviewed:=s.kind='quiz';
 return new;
end; $$;
drop trigger if exists grade_submission_trigger on public.submissions;
create trigger grade_submission_trigger before insert on public.submissions for each row execute function public.grade_submission();
create or replace function public.attach_evidence(p_station_id integer,p_path text) returns void language plpgsql security definer set search_path=public,storage as $$
begin
 if split_part(p_path,'/',1) <> auth.uid()::text then raise exception 'Invalid path'; end if;
 if not exists(select 1 from storage.objects where bucket_id='music-evidence' and name=p_path) then raise exception 'Missing upload'; end if;
 update public.submissions set media_path=p_path where owner=auth.uid() and station_id=p_station_id and media_path is null;
 if not found then raise exception 'Submission not found'; end if;
end; $$;
revoke all on function public.attach_evidence(integer,text) from public;
grant execute on function public.attach_evidence(integer,text) to authenticated;