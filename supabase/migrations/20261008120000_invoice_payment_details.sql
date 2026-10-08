-- Bank details printed on invoices, so clients know where to pay.
insert into public.settings (key, value, description) values
  ('invoice_payment_details', '""',
   'Bank name, account name, account number, branch code and account type, printed on every invoice under "How to pay".')
on conflict (key) do nothing;
