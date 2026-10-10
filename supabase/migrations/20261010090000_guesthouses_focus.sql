-- Guesthouses are a phase 1 focus industry in the business plan. They were
-- listed as the "Accommodation" candidate; rename and promote them.
update public.industries
set name = 'Guesthouses and B&Bs', focus_status = 'focus', sort_order = 35
where name = 'Accommodation';
