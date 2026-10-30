-- The industries in the business plan's target market, for the Get started
-- form. Phase 1 (caterers and event companies, guesthouses, salons,
-- restaurants) and phase 2 (auto repair, cleaning and security, tutoring
-- centres, gyms) are focus industries. Micro-lenders (phase 3) are left out
-- until the compliance features are ready.
update public.industries set name = 'Caterers and event companies' where name = 'Caterers';

insert into public.industries (name, focus_status, sort_order) values
  ('Auto repair shops', 'focus', 40),
  ('Cleaning and security', 'focus', 45),
  ('Tutoring centres', 'focus', 50),
  ('Gyms and fitness', 'focus', 55)
on conflict (name) do update set focus_status = excluded.focus_status, sort_order = excluded.sort_order, active = true;

-- Other options follow the focus industries.
update public.industries set sort_order = 80 where name = 'Construction and trades';
update public.industries set sort_order = 85 where name = 'Professional services';
update public.industries set sort_order = 90 where name = 'Retail';
