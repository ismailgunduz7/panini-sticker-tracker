-- The push Edge Function reads device tokens with the service role and prunes
-- dead ones. service_role bypasses RLS but still needs table-level privileges,
-- which the original device_tokens migration only granted to authenticated.
-- Without this the function fails with "permission denied for table
-- device_tokens" (42501) and delivers nothing.

grant select, delete on public.device_tokens to service_role;
