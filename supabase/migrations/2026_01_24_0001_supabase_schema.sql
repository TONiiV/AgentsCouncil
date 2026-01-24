-- AgentsCouncil Supabase Schema Migration
-- Creates tables with owner_id/guest_id for per-user isolation and RLS policies

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- COUNCILS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS councils (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    max_rounds INTEGER NOT NULL,
    consensus_threshold REAL NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    owner_id UUID NULL,
    guest_id UUID NULL
);

-- Indexes for owner/guest filtering
CREATE INDEX IF NOT EXISTS idx_councils_owner_id ON councils(owner_id);
CREATE INDEX IF NOT EXISTS idx_councils_guest_id ON councils(guest_id);

-- Enable RLS
ALTER TABLE councils ENABLE ROW LEVEL SECURITY;

-- RLS Policies for councils
-- Owners can see their own councils
-- Note: Guest access is handled by backend filtering (service role bypasses RLS)
CREATE POLICY councils_select_owner ON councils
    FOR SELECT
    USING (owner_id = auth.uid());

-- Owners can insert their own councils
CREATE POLICY councils_insert_owner ON councils
    FOR INSERT
    WITH CHECK (owner_id = auth.uid() OR owner_id IS NULL);

-- Owners can update their own councils
CREATE POLICY councils_update_owner ON councils
    FOR UPDATE
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

-- Owners can delete their own councils
CREATE POLICY councils_delete_owner ON councils
    FOR DELETE
    USING (owner_id = auth.uid());

-- =============================================================================
-- COUNCIL_AGENTS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS council_agents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    council_id UUID NOT NULL REFERENCES councils(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    provider TEXT NOT NULL,
    role TEXT NOT NULL,
    custom_prompt TEXT,
    model TEXT,
    sort_order INTEGER NOT NULL
);

-- Index for council lookup
CREATE INDEX IF NOT EXISTS idx_council_agents_council_id ON council_agents(council_id);

-- Enable RLS (inherits access through councils)
ALTER TABLE council_agents ENABLE ROW LEVEL SECURITY;

-- RLS Policies for council_agents (inherit through council)
CREATE POLICY council_agents_select ON council_agents
    FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM councils
        WHERE councils.id = council_agents.council_id
        AND councils.owner_id = auth.uid()
    ));

CREATE POLICY council_agents_insert ON council_agents
    FOR INSERT
    WITH CHECK (EXISTS (
        SELECT 1 FROM councils
        WHERE councils.id = council_agents.council_id
        AND (councils.owner_id = auth.uid() OR councils.owner_id IS NULL)
    ));

CREATE POLICY council_agents_update ON council_agents
    FOR UPDATE
    USING (EXISTS (
        SELECT 1 FROM councils
        WHERE councils.id = council_agents.council_id
        AND councils.owner_id = auth.uid()
    ));

CREATE POLICY council_agents_delete ON council_agents
    FOR DELETE
    USING (EXISTS (
        SELECT 1 FROM councils
        WHERE councils.id = council_agents.council_id
        AND councils.owner_id = auth.uid()
    ));

-- =============================================================================
-- DEBATES TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS debates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    council_id UUID NOT NULL REFERENCES councils(id) ON DELETE CASCADE,
    topic TEXT NOT NULL,
    status TEXT NOT NULL,
    current_round INTEGER NOT NULL DEFAULT 0,
    summary TEXT,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    owner_id UUID NULL,
    guest_id UUID NULL
);

-- Indexes for owner/guest filtering and council lookup
CREATE INDEX IF NOT EXISTS idx_debates_owner_id ON debates(owner_id);
CREATE INDEX IF NOT EXISTS idx_debates_guest_id ON debates(guest_id);
CREATE INDEX IF NOT EXISTS idx_debates_council_id ON debates(council_id);

-- Enable RLS
ALTER TABLE debates ENABLE ROW LEVEL SECURITY;

-- RLS Policies for debates
-- Note: Guest access is handled by backend filtering (service role bypasses RLS)
CREATE POLICY debates_select_owner ON debates
    FOR SELECT
    USING (owner_id = auth.uid());

CREATE POLICY debates_insert_owner ON debates
    FOR INSERT
    WITH CHECK (owner_id = auth.uid() OR owner_id IS NULL);

CREATE POLICY debates_update_owner ON debates
    FOR UPDATE
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY debates_delete_owner ON debates
    FOR DELETE
    USING (owner_id = auth.uid());

-- =============================================================================
-- DEBATE_ROUNDS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS debate_rounds (
    id SERIAL PRIMARY KEY,
    debate_id UUID NOT NULL REFERENCES debates(id) ON DELETE CASCADE,
    round_number INTEGER NOT NULL,
    consensus_reached BOOLEAN NOT NULL DEFAULT FALSE,
    vote_summary_agree INTEGER,
    vote_summary_disagree INTEGER,
    vote_summary_abstain INTEGER,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for debate lookup
CREATE INDEX IF NOT EXISTS idx_debate_rounds_debate_id ON debate_rounds(debate_id);

-- Enable RLS (inherits access through debates)
ALTER TABLE debate_rounds ENABLE ROW LEVEL SECURITY;

-- RLS Policies for debate_rounds (inherit through debate)
CREATE POLICY debate_rounds_select ON debate_rounds
    FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM debates
        WHERE debates.id = debate_rounds.debate_id
        AND debates.owner_id = auth.uid()
    ));

CREATE POLICY debate_rounds_insert ON debate_rounds
    FOR INSERT
    WITH CHECK (EXISTS (
        SELECT 1 FROM debates
        WHERE debates.id = debate_rounds.debate_id
        AND (debates.owner_id = auth.uid() OR debates.owner_id IS NULL)
    ));

CREATE POLICY debate_rounds_update ON debate_rounds
    FOR UPDATE
    USING (EXISTS (
        SELECT 1 FROM debates
        WHERE debates.id = debate_rounds.debate_id
        AND debates.owner_id = auth.uid()
    ));

CREATE POLICY debate_rounds_delete ON debate_rounds
    FOR DELETE
    USING (EXISTS (
        SELECT 1 FROM debates
        WHERE debates.id = debate_rounds.debate_id
        AND debates.owner_id = auth.uid()
    ));

-- =============================================================================
-- DEBATE_RESPONSES TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS debate_responses (
    id SERIAL PRIMARY KEY,
    debate_id UUID NOT NULL REFERENCES debates(id) ON DELETE CASCADE,
    round_number INTEGER NOT NULL,
    agent_id UUID NOT NULL,
    agent_name TEXT NOT NULL,
    role TEXT NOT NULL,
    provider TEXT NOT NULL,
    content TEXT NOT NULL,
    vote TEXT,
    reasoning TEXT,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for debate lookup
CREATE INDEX IF NOT EXISTS idx_debate_responses_debate_id ON debate_responses(debate_id);

-- Enable RLS (inherits access through debates)
ALTER TABLE debate_responses ENABLE ROW LEVEL SECURITY;

-- RLS Policies for debate_responses (inherit through debate)
CREATE POLICY debate_responses_select ON debate_responses
    FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM debates
        WHERE debates.id = debate_responses.debate_id
        AND debates.owner_id = auth.uid()
    ));

CREATE POLICY debate_responses_insert ON debate_responses
    FOR INSERT
    WITH CHECK (EXISTS (
        SELECT 1 FROM debates
        WHERE debates.id = debate_responses.debate_id
        AND (debates.owner_id = auth.uid() OR debates.owner_id IS NULL)
    ));

CREATE POLICY debate_responses_update ON debate_responses
    FOR UPDATE
    USING (EXISTS (
        SELECT 1 FROM debates
        WHERE debates.id = debate_responses.debate_id
        AND debates.owner_id = auth.uid()
    ));

CREATE POLICY debate_responses_delete ON debate_responses
    FOR DELETE
    USING (EXISTS (
        SELECT 1 FROM debates
        WHERE debates.id = debate_responses.debate_id
        AND debates.owner_id = auth.uid()
    ));

-- =============================================================================
-- DEBATE_VOTES TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS debate_votes (
    id SERIAL PRIMARY KEY,
    debate_id UUID NOT NULL REFERENCES debates(id) ON DELETE CASCADE,
    round_number INTEGER NOT NULL,
    agent_id UUID NOT NULL,
    vote TEXT NOT NULL
);

-- Index for debate lookup
CREATE INDEX IF NOT EXISTS idx_debate_votes_debate_id ON debate_votes(debate_id);

-- Enable RLS (inherits access through debates)
ALTER TABLE debate_votes ENABLE ROW LEVEL SECURITY;

-- RLS Policies for debate_votes (inherit through debate)
CREATE POLICY debate_votes_select ON debate_votes
    FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM debates
        WHERE debates.id = debate_votes.debate_id
        AND debates.owner_id = auth.uid()
    ));

CREATE POLICY debate_votes_insert ON debate_votes
    FOR INSERT
    WITH CHECK (EXISTS (
        SELECT 1 FROM debates
        WHERE debates.id = debate_votes.debate_id
        AND (debates.owner_id = auth.uid() OR debates.owner_id IS NULL)
    ));

CREATE POLICY debate_votes_update ON debate_votes
    FOR UPDATE
    USING (EXISTS (
        SELECT 1 FROM debates
        WHERE debates.id = debate_votes.debate_id
        AND debates.owner_id = auth.uid()
    ));

CREATE POLICY debate_votes_delete ON debate_votes
    FOR DELETE
    USING (EXISTS (
        SELECT 1 FROM debates
        WHERE debates.id = debate_votes.debate_id
        AND debates.owner_id = auth.uid()
    ));

-- =============================================================================
-- DEBATE_POINTS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS debate_points (
    id SERIAL PRIMARY KEY,
    debate_id UUID NOT NULL REFERENCES debates(id) ON DELETE CASCADE,
    point_type TEXT NOT NULL,
    point TEXT NOT NULL,
    sort_order INTEGER NOT NULL
);

-- Index for debate lookup
CREATE INDEX IF NOT EXISTS idx_debate_points_debate_id ON debate_points(debate_id);

-- Enable RLS (inherits access through debates)
ALTER TABLE debate_points ENABLE ROW LEVEL SECURITY;

-- RLS Policies for debate_points (inherit through debate)
CREATE POLICY debate_points_select ON debate_points
    FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM debates
        WHERE debates.id = debate_points.debate_id
        AND debates.owner_id = auth.uid()
    ));

CREATE POLICY debate_points_insert ON debate_points
    FOR INSERT
    WITH CHECK (EXISTS (
        SELECT 1 FROM debates
        WHERE debates.id = debate_points.debate_id
        AND (debates.owner_id = auth.uid() OR debates.owner_id IS NULL)
    ));

CREATE POLICY debate_points_update ON debate_points
    FOR UPDATE
    USING (EXISTS (
        SELECT 1 FROM debates
        WHERE debates.id = debate_points.debate_id
        AND debates.owner_id = auth.uid()
    ));

CREATE POLICY debate_points_delete ON debate_points
    FOR DELETE
    USING (EXISTS (
        SELECT 1 FROM debates
        WHERE debates.id = debate_points.debate_id
        AND debates.owner_id = auth.uid()
    ));
