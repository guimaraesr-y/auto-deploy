
SECURITY LABEL FOR anon ON COLUMN payments_user.email
  IS 'MASKED WITH FUNCTION anon.fake_email()';

SECURITY LABEL FOR anon ON COLUMN payments_user.last_name
  IS 'MASKED WITH FUNCTION anon.fake_last_name()';

