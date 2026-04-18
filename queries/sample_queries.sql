-- Queries de exemplo para Athena

-- 1. Ver todas as vendas processadas
SELECT * 
FROM consolidated_vendas 
LIMIT 10;

-- 2. Total de vendas por produto
SELECT 
    produto,
    COUNT(*) as quantidade_vendas,
    SUM(valor) as valor_total,
    AVG(valor) as valor_medio
FROM consolidated_vendas
GROUP BY produto
ORDER BY valor_total DESC;

-- 3. Vendas por CEP
SELECT 
    cep,
    COUNT(*) as total_vendas,
    SUM(valor) as valor_total
FROM consolidated_vendas
GROUP BY cep
ORDER BY total_vendas DESC;

-- 4. Join vendas com clientes
SELECT 
    v.id as venda_id,
    v.produto,
    v.valor,
    v.data_venda,
    c.nome as cliente_nome,
    c.email as cliente_email,
    c.cidade,
    c.estado
FROM consolidated_vendas v
LEFT JOIN consolidated_clientes c ON v.cliente_id = c.id
ORDER BY v.data_venda DESC;

-- 5. Análise de clientes por estado
SELECT 
    estado,
    COUNT(*) as total_clientes
FROM consolidated_clientes
GROUP BY estado
ORDER BY total_clientes DESC;

-- 6. Dados da API CEP
SELECT 
    cep,
    city as cidade,
    state as estado,
    address as endereco,
    fetched_at
FROM consolidated_cep
ORDER BY fetched_at DESC;

-- 7. Vendas com informações de localização da API
SELECT 
    v.produto,
    v.valor,
    v.data_venda,
    api.city as cidade_api,
    api.state as estado_api,
    api.address as endereco_completo
FROM consolidated_vendas v
LEFT JOIN consolidated_cep api ON v.cep = api.cep
WHERE api.cep IS NOT NULL;

-- 8. Metadata do job
SELECT 
    job_name,
    execution_time,
    vendas_count,
    clientes_count,
    cep_count,
    status
FROM metadata
ORDER BY execution_time DESC
LIMIT 10;

-- 9. Análise temporal de vendas
SELECT 
    DATE_TRUNC('month', CAST(data_venda AS DATE)) as mes,
    COUNT(*) as total_vendas,
    SUM(valor) as receita_total
FROM consolidated_vendas
GROUP BY DATE_TRUNC('month', CAST(data_venda AS DATE))
ORDER BY mes;

-- 10. Top 5 clientes por valor de compras
SELECT 
    c.nome,
    c.email,
    c.cidade,
    COUNT(v.id) as total_compras,
    SUM(v.valor) as valor_total_gasto
FROM consolidated_clientes c
LEFT JOIN consolidated_vendas v ON c.id = v.cliente_id
GROUP BY c.nome, c.email, c.cidade
ORDER BY valor_total_gasto DESC
LIMIT 5;
