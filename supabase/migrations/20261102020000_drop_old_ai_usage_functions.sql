-- Both functions now pass a kind; the old signatures can go.
drop function public.take_ai_call(uuid, integer, integer);
drop function public.refund_ai_call(uuid);
