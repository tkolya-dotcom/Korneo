-- Дополнительные триггеры для warehouse (запустить в Supabase SQL Editor)

-- Функция получения текущего остатка
CREATE OR REPLACE FUNCTION public.get_warehouse_stock(material_id_param uuid)
RETURNS TABLE(total numeric) AS $$
BEGIN
  RETURN QUERY
  SELECT COALESCE(SUM(quantity), 0)::numeric
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

-- Триггер: prevent negative stock
CREATE OR REPLACE FUNCTION public.prevent_negative_stock()
RETURNS trigger AS $$
DECLARE
  current_stock numeric;
BEGIN
  SELECT COALESCE(SUM(quantity), 0) INTO current_stock 
  FROM public.warehouse WHERE material_id = NEW.material_id;
  
  IF current_stock + NEW.quantity < 0 THEN
    RAISE EXCEPTION 'Недостаточно товара на складе. Попытка отрицательного остатка %', (current_stock + NEW.quantity);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_negative_stock
  BEFORE INSERT OR UPDATE ON public.warehouse
  FOR EACH ROW EXECUTE FUNCTION public.prevent_negative_stock();

