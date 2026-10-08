-- Website intake: the Get started form, consent records and slot booking.
begin;

select id as salon_id from public.industries where name = 'Salons and beauty' \gset

insert into public.booking_slots (starts_at, ends_at, mode, location) values
  (now() + interval '3 days', now() + interval '3 days 1 hour', 'in_person', 'Client premises'),
  (now() + interval '4 days', now() + interval '4 days 1 hour', 'online', null),
  (now() + interval '2 hours', now() + interval '3 hours', 'online', null),        -- too soon to book
  (now() + interval '90 days', now() + interval '90 days 1 hour', 'online', null); -- beyond the window
select id as slot_id from public.booking_slots where location = 'Client premises' \gset

-- Signed-in staff can't call the intake functions directly; only edge functions can.
select tests.create_staff('founder@isangotech.co.za') as admin_id \gset
select tests.sign_in(:'admin_id');
set local role authenticated;
select tests.expect_error($$select public.submit_enquiry('{}')$$, 'permission denied');
select tests.expect_error($$select public.enquiry_options()$$, 'permission denied');
reset role;

set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);

-- Form options: active industries in order, only bookable slots, policy version.
do $$
declare o jsonb := public.enquiry_options();
begin
  assert o -> 'industries' -> 0 ->> 'name' = 'Salons and beauty', 'focus industries come first';
  assert jsonb_array_length(o -> 'slots') = 2, 'only slots inside the notice and booking window are offered';
  assert o ->> 'privacy_policy_version' = '1', 'current privacy policy version is returned';
  assert not (o::text like '%Client premises%'), 'slot locations are not exposed publicly';
end $$;

-- Validation.
select tests.expect_error($$select public.submit_enquiry('{"full_name":"Thandi","phone":"0821234567"}')$$, 'agree to the privacy policy');
select tests.expect_error($$select public.submit_enquiry('{"consent":true,"phone":"0821234567"}')$$, 'your name');
select tests.expect_error($$select public.submit_enquiry('{"consent":true,"full_name":"Thandi","phone":"123"}')$$, 'phone number');
select tests.expect_error($$select public.submit_enquiry('{"consent":true,"full_name":"Thandi","phone":"0821234567","email":"nope"}')$$, 'email address');
select tests.expect_error($$select public.submit_enquiry('{"consent":true,"full_name":"Thandi","phone":"0821234567","stage_needed":7}')$$, 'growth stage');
select tests.expect_error($$select public.submit_enquiry('{"consent":true,"full_name":"Thandi","phone":"0821234567","industry_id":"not-a-uuid"}')$$, 'wrong format');
select tests.expect_error($$select public.submit_enquiry('{"consent":"maybe","full_name":"Thandi","phone":"0821234567"}')$$, 'wrong format');

-- A full enquiry with a WhatsApp opt-in and a booking.
select public.submit_enquiry(jsonb_build_object(
  'full_name', '  Thandi Mbeki ',
  'business_name', 'Thandi''s Hair Studio',
  'industry_id', :'salon_id',
  'phone', '082 123 4567',
  'email', 'Thandi@Example.co.za',
  'stage_needed', 2,
  'biggest_pain', 'Missed bookings on WhatsApp',
  'consent', true,
  'whatsapp_opt_in', true,
  'booking_slot_id', :'slot_id'
)) ->> 'lead_id' as lead_id \gset

reset role;
select set_config('vars.lead_id', :'lead_id', true);

do $$
declare
  l public.leads;
begin
  select * into l from public.leads where id = current_setting('vars.lead_id')::uuid;
  assert l.full_name = 'Thandi Mbeki', 'name is trimmed';
  assert l.phone = '0821234567', 'phone is normalised';
  assert l.email = 'thandi@example.co.za', 'email is lower-cased';
  assert l.source = 'website_form', 'source is the website form';
  assert l.pipeline_stage = 'assessment', 'booking moves the lead to assessment';
  assert l.created_by is null, 'website leads have no staff author';
  assert (select count(*) from public.consents where lead_id = l.id) = 2, 'enquiry and WhatsApp consents recorded';
  assert (select privacy_policy_version from public.consents where lead_id = l.id and purpose = 'enquiry') = '1',
    'consent records the policy version';
  assert (select status from public.booking_slots where location = 'Client premises') = 'booked', 'slot is booked';
  assert (select scheduled_at from public.assessments where lead_id = l.id)
       = (select starts_at from public.booking_slots where location = 'Client premises'), 'assessment takes the slot time';
end $$;

-- The same slot can't be booked twice, and a failed booking leaves no lead behind.
set local role service_role;
select tests.expect_error(format($$select public.submit_enquiry('{"consent":true,"full_name":"Sipho","phone":"0731234567","booking_slot_id":"%s"}')$$, :'slot_id'), 'just been taken');
reset role;
do $$ begin
  assert not exists (select 1 from public.leads where full_name = 'Sipho'), 'failed booking rolls back the lead';
end $$;

-- A minimal enquiry without email, stage, industry or booking.
set local role service_role;
select public.submit_enquiry('{"consent":true,"full_name":"Sipho","phone":"+27731234567"}');
reset role;
do $$ begin
  assert (select pipeline_stage from public.leads where full_name = 'Sipho') = 'new', 'plain enquiry starts as new';
  assert (select count(*) from public.consents c join public.leads l on l.id = c.lead_id where l.full_name = 'Sipho') = 1,
    'only the enquiry consent without a WhatsApp opt-in';
end $$;

rollback;
