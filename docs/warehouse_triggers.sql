-- ============================================================
-- Триггеры для warehouse
-- Запускать в Supabase SQL Editor
-- ============================================================

-- Функция получения текущего остатка
CREATE OR REPLACE FUNCTION public.get_warehouse_stock(material_id_param uuid)
RETURNS TABLE(total numeric) AS $$
BEGIN
  RETURN QUERY
  SELECT COALESCE(SUM(quantity_available), 0)::numeric
  FROM public.warehouse 
  WHERE material_id = material_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Индекс для быстрого поиска по material_id
CREATE INDEX IF NOT EXISTS idx_warehouse_material_updated ON public.warehouse (material_id, updated_at DESC);

-- RLS для warehouse (manager+ read/write)
CREATE POLICY "Warehouse readable by authenticated" ON public.warehouse FOR SELECT TO authenticated USING (true);
CREATE POLICY "Warehouse manager update" ON public.warehouse FOR ALL TO authenticated 
  USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('manager', 'deputy_head', 'admin')))
  WITH CHECK (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('manager', 'deputy_head', 'admin')));


-- ============================================================
-- ЛОГИКА ОТРИЦАТЕЛЬНОГО ОСТАТКА
--
-- Вместо запрета уходить в минус:
--   1. Операция списания проходит (остаток может стать отрицательным)
--   2. Автоматически создаётся purchase_request на восполнение дефицита
--   3. Руководитель (manager / deputy_head / admin) получает уведомление
-- ============================================================

-- Вспомогательная функция: генерация short_id для purchase_requests
CREATE OR REPLACE FUNCTION public.get_next_purchase_request_short_id()
RETURNS text AS $$
DECLARE
  next_id bigint;
BEGIN
  SELECT COALESCE(last_id, 0) + 1 INTO next_id
  FROM public.id_counters
  WHERE entity_type = 'purchase_request'
  FOR UPDATE;

  IF next_id IS NULL THEN
    next_id := 1;
    INSERT INTO public.id_counters (entity_type, last_id) VALUES ('purchase_request', 1);
  ELSE
    UPDATE public.id_counters SET last_id = next_id WHERE entity_type = 'purchase_request';
  END IF;

  RETURN 'PR-' || lpad(next_id::text, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Триггерная функция: после обновления остатка проверяем дефицит
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_negative_stock()
RETURNS trigger AS $$
DECLARE
  total_stock      numeric;
  mat_name         text;
  mat_unit         text;
  deficit          numeric;
  new_request_id   uuid;
  short_id_val     text;
  manager_id       uuid;
BEGIN
  -- Считаем суммарный остаток ПОСЛЕ изменения
  SELECT COALESCE(SUM(quantity_available), 0) INTO total_stock
  FROM public.warehouse
  WHERE material_id = NEW.material_id;

  -- Если остаток неотрицательный — ничего не делаем
  IF total_stock >= 0 THEN
    RETURN NEW;
  END IF;

  -- Получаем данные о материале
  SELECT name, unit INTO mat_name, mat_unit
  FROM public.materials
  WHERE id = NEW.material_id;

  deficit := ABS(total_stock); -- сколько не хватает

  -- Берём первого руководителя (manager / deputy_head / admin)
  SELECT id INTO manager_id
  FROM public.users
  WHERE role IN ('manager', 'deputy_head', 'admin')
  ORDER BY created_at
  LIMIT 1;

  -- Генерируем short_id
  short_id_val := public.get_next_purchase_request_short_id();

  -- Создаём заявку на закупку
  INSERT INTO public.purchase_requests (
    requester_id,
    status,
    comment,
    short_id
  )
  VALUES (
    manager_id,
    'pending',
    format(
      'Автозаявка: дефицит материала «%s» составил %s %s. Создана автоматически при списании.',
      mat_name, deficit, COALESCE(mat_unit, 'шт')
    ),
    short_id_val
  )
  RETURNING id INTO new_request_id;

  -- Добавляем строку позиции
  INSERT INTO public.purchase_request_items (
    request_id,
    material_id,
    quantity,
    unit,
    name
  )
  VALUES (
    new_request_id,
    NEW.material_id,
    deficit,
    COALESCE(mat_unit, 'шт'),
    COALESCE(mat_name, 'Неизвестный материал')
  );

  -- Уведомление руководителю (если таблица notifications существует)
  -- Supabase Realtime сам разошлёт изменение по подписке на purchase_requests
  -- Дополнительно пишем в notifications для in-app алерта
  BEGIN
    INSERT INTO public.notifications (
      user_id,
      type,
      title,
      body,
      reference_id,
      reference_type,
      is_read,
      created_at
    )
    VALUES (
      manager_id,
      'stock_deficit',
      'Дефицит на складе',
      format(
        'Остаток «%s» ушёл в минус (%s %s). Автоматически создана заявка на закупку %s.',
        mat_name, total_stock, COALESCE(mat_unit, 'шт'), short_id_val
      ),
      new_request_id,
      'purchase_request',
      false,
      now()
    );
  EXCEPTION WHEN undefined_table THEN
    -- таблица notifications ещё не создана — пропускаем
    NULL;
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Триггер: ПОСЛЕ INSERT/UPDATE на warehouse
DROP TRIGGER IF EXISTS trg_handle_negative_stock ON public.warehouse;
CREATE TRIGGER trg_handle_negative_stock
  AFTER INSERT OR UPDATE ON public.warehouse
  FOR EACH ROW EXECUTE FUNCTION public.handle_negative_stock();


-- ============================================================
-- СТАРЫЙ триггер prevent_negative_stock УДАЛЯЕМ
-- (теперь уход в минус разрешён, но порождает автозаявку)
-- ============================================================
DROP TRIGGER IF EXISTS trg_prevent_negative_stock ON public.warehouse;
DROP FUNCTION IF EXISTS public.prevent_negative_stock();


-- ============================================================
-- RLS: уведомления
-- ============================================================
ALTER TABLE IF EXISTS public.notifications ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'notifications' AND policyname = 'Notifications own user'
  ) THEN
    CREATE POLICY "Notifications own user" ON public.notifications
      FOR ALL TO authenticated
      USING (user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid()))
      WITH CHECK (user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid()));
  END IF;
END $$;
