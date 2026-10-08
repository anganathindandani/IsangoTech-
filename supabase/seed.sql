-- Sample data for local development only (`supabase db reset`). Never run
-- against the live project. Prices are placeholders, not real prices.

insert into public.packages (name, growth_stage, description, price, billing) values
  ('Starter website (EXAMPLE)', 1, 'Placeholder until the Starter package name and price are decided.', 0, 'once_off'),
  ('Core Starter (EXAMPLE)', 2, 'Booking forms, lead tracking and WhatsApp follow-ups.', 0, 'once_off'),
  ('Core Business (EXAMPLE)', 3, 'Operations portal: events, staff, menus, stock, invoices.', 0, 'once_off'),
  ('AI Readiness Assessment (EXAMPLE)', 4, 'On-site assessment and written recommendations.', 0, 'once_off'),
  ('Care plan (EXAMPLE)', null, 'Hosting, updates and support.', 0, 'monthly');

-- Open assessment slots on weekday mornings for the next two weeks.
insert into public.booking_slots (starts_at, ends_at, mode, location)
select
  (d + time '09:00') at time zone 'Africa/Johannesburg',
  (d + time '10:30') at time zone 'Africa/Johannesburg',
  case when extract(isodow from d) in (2, 4) then 'online' else 'in_person' end,
  case when extract(isodow from d) in (2, 4) then null else 'Client premises, East London' end
from generate_series(current_date + 2, current_date + 15, interval '1 day') as d
where extract(isodow from d) between 1 and 5;
