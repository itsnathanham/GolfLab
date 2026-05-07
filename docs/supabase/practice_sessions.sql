-- GolfLab — practice_sessions (run in Supabase SQL editor)
-- One row per user per calendar day append-only session log (multiple focus flags OK).

CREATE TABLE IF NOT EXISTS public.practice_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    session_date DATE NOT NULL,
    practiced_range BOOLEAN NOT NULL DEFAULT FALSE,
    practiced_chipping BOOLEAN NOT NULL DEFAULT FALSE,
    practiced_putting BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT practice_sessions_some_focus_chk CHECK (
        practiced_range IS TRUE OR practiced_chipping IS TRUE OR practiced_putting IS TRUE
    )
);

CREATE INDEX IF NOT EXISTS practice_sessions_user_date_idx
    ON public.practice_sessions (user_id, session_date DESC);

ALTER TABLE public.practice_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own practice sessions"
    ON public.practice_sessions
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users insert own practice sessions"
    ON public.practice_sessions
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- v1 append-only — no UPDATE / DELETE policies
