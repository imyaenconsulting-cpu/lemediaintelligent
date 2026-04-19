-- ═══════════════════════════════════════════════════════════════════
-- SCHÉMA SUPABASE COMPLET — LE MÉDIA INTELLIGENT + SKYLENS
-- Copiez-collez ce code entier dans Supabase > SQL Editor > New Query
-- Puis cliquez sur le bouton vert "Run"
-- ═══════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────────
-- 1. EXTENSION UUID (nécessaire)
-- ───────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ───────────────────────────────────────────────────────────────────
-- 2. TABLE UTILISATEURS
-- ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email           TEXT UNIQUE NOT NULL,
  display_name    TEXT,
  avatar_url      TEXT,
  plan            TEXT NOT NULL DEFAULT 'free' CHECK (plan IN ('free','premium','pro')),
  plan_expires_at TIMESTAMP WITH TIME ZONE,
  stripe_customer_id TEXT UNIQUE,
  stripe_subscription_id TEXT UNIQUE,
  referral_code   TEXT UNIQUE DEFAULT SUBSTRING(MD5(RANDOM()::TEXT), 1, 8),
  referred_by     UUID REFERENCES public.users(id),
  referral_count  INTEGER DEFAULT 0,
  is_admin        BOOLEAN DEFAULT FALSE,
  language        TEXT DEFAULT 'fr',
  format_pref     TEXT DEFAULT 'text' CHECK (format_pref IN ('text','audio','video')),
  offline_enabled BOOLEAN DEFAULT FALSE,
  push_enabled    BOOLEAN DEFAULT FALSE,
  email_notifs    BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_login_at   TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ───────────────────────────────────────────────────────────────────
-- 3. TABLE ARTICLES (Média Intelligent)
-- ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.articles (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title           TEXT NOT NULL,
  content         TEXT NOT NULL,
  excerpt         TEXT,
  category        TEXT NOT NULL,
  subcategory     TEXT,
  language        TEXT DEFAULT 'fr',
  fact_score      INTEGER CHECK (fact_score BETWEEN 0 AND 100),
  reliability     TEXT DEFAULT 'verified' CHECK (reliability IN ('verified','unverified','disputed','fake')),
  ai_generated    BOOLEAN DEFAULT FALSE,
  sources         JSONB DEFAULT '[]',
  tags            TEXT[] DEFAULT '{}',
  from_skylens    BOOLEAN DEFAULT FALSE,
  skylens_alert_id UUID,
  sentiment       TEXT CHECK (sentiment IN ('positive','negative','neutral')),
  views           INTEGER DEFAULT 0,
  shares          INTEGER DEFAULT 0,
  audio_url       TEXT,
  video_url       TEXT,
  image_url       TEXT,
  reading_time    INTEGER DEFAULT 3,
  published_at    TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ───────────────────────────────────────────────────────────────────
-- 4. TABLE FAKE NEWS
-- ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.fake_news (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title           TEXT NOT NULL,
  description     TEXT,
  severity        TEXT NOT NULL DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  reach_count     INTEGER DEFAULT 0,
  platform        TEXT,
  debunk_article_id UUID REFERENCES public.articles(id),
  topics          TEXT[] DEFAULT '{}',
  detected_at     TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  verified_at     TIMESTAMP WITH TIME ZONE,
  is_active       BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ───────────────────────────────────────────────────────────────────
-- 5. TABLE SKYLENS — ALERTES OSINT
-- ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.skylens_alerts (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  alert_type      TEXT NOT NULL CHECK (alert_type IN ('transponder_off','route_anomaly','dense_traffic','military','satellite','unknown')),
  severity        TEXT NOT NULL DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  title           TEXT NOT NULL,
  description     TEXT,
  latitude        DECIMAL(9,6),
  longitude       DECIMAL(9,6),
  zone_name       TEXT,
  entity_id       TEXT,
  entity_type     TEXT CHECK (entity_type IN ('plane','ship','satellite','unknown')),
  raw_data        JSONB DEFAULT '{}',
  ai_analysis     TEXT,
  article_generated BOOLEAN DEFAULT FALSE,
  article_id      UUID REFERENCES public.articles(id),
  is_active       BOOLEAN DEFAULT TRUE,
  resolved_at     TIMESTAMP WITH TIME ZONE,
  detected_at     TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ───────────────────────────────────────────────────────────────────
-- 6. TABLE SKYLENS — DONNÉES TRAFIC (cache ADS-B / AIS)
-- ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.traffic_cache (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  entity_type     TEXT NOT NULL CHECK (entity_type IN ('plane','ship','satellite')),
  entity_id       TEXT NOT NULL,
  callsign        TEXT,
  latitude        DECIMAL(9,6),
  longitude       DECIMAL(9,6),
  altitude        INTEGER,
  speed           DECIMAL(6,1),
  heading         DECIMAL(5,1),
  is_military     BOOLEAN DEFAULT FALSE,
  transponder_on  BOOLEAN DEFAULT TRUE,
  raw_data        JSONB DEFAULT '{}',
  fetched_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ───────────────────────────────────────────────────────────────────
-- 7. TABLE PRÉFÉRENCES UTILISATEUR (lecture + personnalisation)
-- ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_preferences (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  topics          TEXT[] DEFAULT '{}',
  avoided_topics  TEXT[] DEFAULT '{}',
  reading_speed   TEXT DEFAULT 'normal' CHECK (reading_speed IN ('quick','normal','deep')),
  skylens_zones   TEXT[] DEFAULT '{}',
  alert_types     TEXT[] DEFAULT '{}',
  created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id)
);

-- ───────────────────────────────────────────────────────────────────
-- 8. TABLE HISTORIQUE LECTURE (pour personnalisation IA)
-- ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.reading_history (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  article_id      UUID NOT NULL REFERENCES public.articles(id) ON DELETE CASCADE,
  read_duration   INTEGER DEFAULT 0,
  read_percent    INTEGER DEFAULT 0 CHECK (read_percent BETWEEN 0 AND 100),
  bookmarked      BOOLEAN DEFAULT FALSE,
  shared          BOOLEAN DEFAULT FALSE,
  rated           INTEGER CHECK (rated BETWEEN 1 AND 5),
  created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ───────────────────────────────────────────────────────────────────
-- 9. TABLE FEEDBACKS (auto-amélioration IA)
-- ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.feedbacks (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID REFERENCES public.users(id) ON DELETE SET NULL,
  type            TEXT NOT NULL CHECK (type IN ('bug','feature','data','osint','other')),
  page            TEXT,
  description     TEXT NOT NULL,
  browser_info    TEXT,
  status          TEXT DEFAULT 'pending' CHECK (status IN ('pending','reviewed','implemented','rejected')),
  ai_patch        TEXT,
  pr_url          TEXT,
  created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ───────────────────────────────────────────────────────────────────
-- 10. TABLE RAPPORTS OSINT (générés par IA)
-- ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.osint_reports (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title           TEXT NOT NULL,
  content         TEXT NOT NULL,
  report_type     TEXT DEFAULT 'global' CHECK (report_type IN ('global','zone','entity','weekly','custom')),
  zone            TEXT,
  alert_ids       UUID[] DEFAULT '{}',
  generated_by    TEXT DEFAULT 'ai',
  plan_required   TEXT DEFAULT 'premium' CHECK (plan_required IN ('free','premium','pro')),
  views           INTEGER DEFAULT 0,
  pdf_url         TEXT,
  created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ───────────────────────────────────────────────────────────────────
-- 11. TABLE PAIEMENTS STRIPE
-- ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.payments (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  stripe_payment_id TEXT UNIQUE,
  amount          INTEGER NOT NULL,
  currency        TEXT DEFAULT 'eur',
  plan            TEXT NOT NULL,
  status          TEXT NOT NULL CHECK (status IN ('succeeded','pending','failed','refunded')),
  description     TEXT,
  created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ───────────────────────────────────────────────────────────────────
-- 12. TABLE LOGS ADMIN (audit complet)
-- ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.admin_logs (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  action          TEXT NOT NULL,
  entity_type     TEXT,
  entity_id       TEXT,
  details         JSONB DEFAULT '{}',
  ip_address      TEXT,
  user_agent      TEXT,
  created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ───────────────────────────────────────────────────────────────────
-- 13. TABLE NEWSLETTER ABONNÉS
-- ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.newsletter_subscribers (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email           TEXT UNIQUE NOT NULL,
  user_id         UUID REFERENCES public.users(id) ON DELETE SET NULL,
  frequency       TEXT DEFAULT 'weekly' CHECK (frequency IN ('daily','weekly')),
  language        TEXT DEFAULT 'fr',
  is_active       BOOLEAN DEFAULT TRUE,
  subscribed_at   TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  unsubscribed_at TIMESTAMP WITH TIME ZONE
);

-- ───────────────────────────────────────────────────────────────────
-- 14. TABLE TENDANCES SOCIALES
-- ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.social_trends (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  hashtag         TEXT NOT NULL,
  platform        TEXT,
  mention_count   INTEGER DEFAULT 0,
  sentiment       TEXT CHECK (sentiment IN ('positive','negative','neutral','anxious','excited')),
  is_bot_activity BOOLEAN DEFAULT FALSE,
  is_coordinated  BOOLEAN DEFAULT FALSE,
  topics          TEXT[] DEFAULT '{}',
  detected_at     TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ───────────────────────────────────────────────────────────────────
-- 15. INDEXES (performance)
-- ───────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_articles_category ON public.articles(category);
CREATE INDEX IF NOT EXISTS idx_articles_language ON public.articles(language);
CREATE INDEX IF NOT EXISTS idx_articles_published ON public.articles(published_at DESC);
CREATE INDEX IF NOT EXISTS idx_articles_fact_score ON public.articles(fact_score DESC);
CREATE INDEX IF NOT EXISTS idx_fake_news_active ON public.fake_news(is_active, detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_skylens_alerts_active ON public.skylens_alerts(is_active, detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_skylens_alerts_severity ON public.skylens_alerts(severity);
CREATE INDEX IF NOT EXISTS idx_traffic_cache_type ON public.traffic_cache(entity_type, fetched_at DESC);
CREATE INDEX IF NOT EXISTS idx_reading_history_user ON public.reading_history(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedbacks_status ON public.feedbacks(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_user ON public.payments(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_logs_date ON public.admin_logs(created_at DESC);

-- ───────────────────────────────────────────────────────────────────
-- 16. ROW LEVEL SECURITY (protection des données)
-- ───────────────────────────────────────────────────────────────────
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fake_news ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skylens_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reading_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedbacks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.osint_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_logs ENABLE ROW LEVEL SECURITY;

-- Policies: articles publics en lecture
CREATE POLICY "Articles lisibles par tous" ON public.articles FOR SELECT USING (true);

-- Policies: fake news lisibles par tous
CREATE POLICY "Fake news lisibles par tous" ON public.fake_news FOR SELECT USING (true);

-- Policies: alertes skylens lisibles par tous
CREATE POLICY "Alertes lisibles par tous" ON public.skylens_alerts FOR SELECT USING (true);

-- Policies: tendances lisibles par tous
CREATE POLICY "Tendances lisibles par tous" ON public.social_trends FOR SELECT USING (true);

-- Policies: rapports OSINT selon plan
CREATE POLICY "Rapports selon plan" ON public.osint_reports FOR SELECT
  USING (plan_required = 'free' OR auth.uid() IS NOT NULL);

-- Policies: utilisateur voit ses propres données
CREATE POLICY "Utilisateur ses données" ON public.users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Utilisateur modifie ses données" ON public.users FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Utilisateur son historique" ON public.reading_history FOR ALL
  USING (auth.uid() = user_id);

CREATE POLICY "Utilisateur ses préférences" ON public.user_preferences FOR ALL
  USING (auth.uid() = user_id);

CREATE POLICY "Utilisateur ses paiements" ON public.payments FOR SELECT
  USING (auth.uid() = user_id);

-- Policies: tout le monde peut soumettre un feedback
CREATE POLICY "Feedback public" ON public.feedbacks FOR INSERT WITH CHECK (true);

-- ───────────────────────────────────────────────────────────────────
-- 17. DONNÉES INITIALES DE DÉMONSTRATION
-- ───────────────────────────────────────────────────────────────────

-- Article de démonstration
INSERT INTO public.articles (title, content, excerpt, category, fact_score, ai_generated, sources, tags, from_skylens) VALUES
(
  'SkyLens détecte une anomalie de trafic aérien en Méditerranée orientale',
  'À 04h12 UTC, le système d''analyse automatique de SkyLens a détecté une configuration inhabituelle dans l''espace aérien méditerranéen oriental. Trois aéronefs ont éteint leurs transpondeurs ADS-B simultanément dans une zone sensible.

L''IA a immédiatement croisé ces données avec les informations maritimes disponibles via AIS, les images satellite Sentinel Hub et les données OSINT publiques, dont des rapports récents de Bellingcat et ACLED.

Selon notre analyse, deux scénarios sont plausibles : un exercice militaire non annoncé, ou un mouvement de fret sensible sous pavillon civil. Les patterns de vol antérieurs suggèrent que la première hypothèse est la plus probable avec un indice de confiance de 78%.

Aucune agence officielle n''a confirmé ces informations à l''heure de publication.',
  'SkyLens a identifié 3 aéronefs avec transpondeurs éteints dans une zone sensible. Analyse OSINT complète.',
  'osint',
  96,
  TRUE,
  '["OpenSky Network", "AIS Exchange", "Sentinel Hub", "ACLED"]',
  ARRAY['skylens','méditerranée','aviation','osint','anomalie'],
  TRUE
),
(
  'Tensions commerciales : l''UE et les États-Unis relancent des négociations',
  'Les représentants commerciaux de l''Union européenne et des États-Unis se sont retrouvés à Bruxelles pour reprendre des négociations interrompues depuis plusieurs semaines.

Selon trois sources proches des discussions consultées par Reuters, les deux parties auraient trouvé un terrain d''entente préliminaire sur certains points techniques, ouvrant la voie à un accord plus large d''ici la fin du trimestre.

Notre IA a analysé les implications potentielles pour les marchés : une résolution positive pourrait stimuler les indices boursiers européens de 2 à 4%.',
  'L''UE et les USA reprennent les négociations commerciales après plusieurs semaines de tensions.',
  'geopolitique',
  99,
  FALSE,
  '["Reuters", "Le Monde", "Financial Times"]',
  ARRAY['ue','usa','commerce','économie'],
  FALSE
);

-- Alerte fake news de démonstration
INSERT INTO public.fake_news (title, description, severity, reach_count, platform, topics) VALUES
(
  'Rumeur sur effets secondaires d''un vaccin — non vérifiée',
  'Une information non vérifiée sur des effets secondaires graves d''un vaccin circule massivement sur les réseaux sociaux. Nos sources officielles (OMS, ANSM) n''ont confirmé aucun de ces effets.',
  'high',
  2400000,
  'Twitter/X, Facebook',
  ARRAY['santé','vaccin','désinformation']
),
(
  'Fausse déclaration attribuée à un chef d''État',
  'Une citation fabriquée attribuée à un chef d''État circule massivement. Un démenti officiel a été émis par les services de communication du gouvernement concerné.',
  'critical',
  890000,
  'Twitter/X, Telegram',
  ARRAY['politique','géopolitique','deepfake']
);

-- Alerte SkyLens de démonstration
INSERT INTO public.skylens_alerts (alert_type, severity, title, description, latitude, longitude, zone_name, entity_type) VALUES
(
  'transponder_off',
  'critical',
  'Transponders éteints — Zone Méditerranée orientale',
  '3 aéronefs ont simultanément éteint leurs transpondeurs ADS-B dans une zone sensible à 04h12 UTC.',
  36.5,
  25.3,
  'Méditerranée orientale',
  'plane'
),
(
  'dense_traffic',
  'high',
  'Trafic maritime anormal — Détroit d''Ormuz',
  'Densité de navires 340% supérieure à la moyenne historique détectée dans le détroit.',
  26.5,
  57.0,
  'Détroit d''Ormuz',
  'ship'
);

-- Tendances sociales de démonstration
INSERT INTO public.social_trends (hashtag, platform, mention_count, sentiment, topics) VALUES
('#CriseClimatique', 'Twitter/X', 847000, 'anxious', ARRAY['environnement','climat']),
('#IA2026', 'LinkedIn', 623000, 'positive', ARRAY['technologie','ia']),
('#MarchésBourse', 'Twitter/X', 411000, 'neutral', ARRAY['économie','finance']);

-- ───────────────────────────────────────────────────────────────────
-- 18. FONCTION AUTO-UPDATE updated_at
-- ───────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_articles_updated_at
  BEFORE UPDATE ON public.articles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_preferences_updated_at
  BEFORE UPDATE ON public.user_preferences
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ═══════════════════════════════════════════════════════════════════
-- TERMINÉ ! Votre base de données est prête.
-- Vérifiez dans Supabase > Table Editor que toutes les tables
-- apparaissent dans la liste à gauche.
-- ═══════════════════════════════════════════════════════════════════
