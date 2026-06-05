# road_network_fires

Pipeline que constrói um dataset **por segmento de rodovia e por ano** (2020–2025) para a malha rodoviária federal do Brasil, cruzando quatro fontes de dados e calculando taxas de sinistros e de focos de queimada normalizadas pela exposição ao tráfego.

## Objetivo

Investigar a relação entre queimadas e sinistros de trânsito nas rodovias federais. Para isso, montou-se uma tabela em que **cada linha é um trecho do SNV em um ano**, reunindo:

- `n_focos` — número de focos de queimada num *buffer* ao redor do segmento;
- `n_sinistros` — número de sinistros de trânsito associados ao segmento;
- `fluxo` — volume anual de tráfego no segmento;
- `dist_m` — comprimento do segmento (m);
- `taxa_sinistros` / `taxa_focos` — contagens normalizadas pela exposição (`fluxo × dist_m`).

A junção de todas as fontes é feita pela chave canônica **`id_trecho_`** (com underscore final).

## Fontes de dados

| Fonte | Origem | Formato | Papel |
|-------|--------|---------|-------|
| **SNV** | DNIT — Sistema Nacional de Viação | shapefile | Geometria da malha; espinha em que as demais fontes se juntam |
| **PRF** | Dados abertos da PRF | CSV/ano | Sinistros de trânsito (`sinistros`) |
| **focos** | INPE — Programa Queimadas, satélite AQUA | CSV/ano | Focos de queimada (`focos`) |
| **VDMA / VMDa** | DNIT — Plano Nacional de Contagem de Tráfego (PNCT) | XLSX/ano | Volume médio diário anual de tráfego |

Os arquivos **brutos** ficam em `data_raw/<fonte>/` (não versionado — `gitignored`) e precisam ser obtidos diretamente das fontes acima.

## Estrutura do repositório

```
road_network_fires/
├── _targets.R              # DAG do pipeline (pacote targets)
├── R/
│   ├── dataset.R           # transformações: prepare_*, count_focos, count_sinistros, build_dataset
│   ├── calc.R              # calc_taxas — cálculo das taxas normalizadas
│   └── plot.R              # mapas: prepare_br, mapa_rodovia, calc_limites, salvar_mapas
├── data/
│   ├── snv/   snv.R  + snv.rds      # ingestão manual de cada fonte:
│   ├── prf/   prf.R  + prf.rds      #   <fonte>.R lê de data_raw/ e grava o .rds limpo
│   ├── focos/ focos.R + focos.rds
│   └── vdma/  vdma.R + vdma.rds
├── plots/                  # mapas PNG gerados pelo pipeline
├── rproject.toml           # dependências declaradas (gestão via rv)
├── rv.lock                 # versões fixadas
├── .Rprofile               # ativa a biblioteca do projeto na inicialização
└── _targets/               # cache do pipeline
```

## Pré-requisitos e instalação

- **R 4.4**.

- **[`rv`](https://github.com/A2-ai/rv)** instalado e disponível no `PATH`. O `.Rprofile` ativa a biblioteca do projeto na abertura da sessão.

- Restaurar a biblioteca, dentro do R, com:

```r
.rv$sync()          # instala/restaura conforme rproject.toml + rv.lock
```

Pacotes-chave: `sf`, `dplyr`, `tidyr`, `lubridate`, `targets`, `ggplot2`, `geobr`, `readxl`, `readr`, `purrr`, `stringr`.

- Obter os dados brutos e colocá-los em `data_raw/<fonte>/` (não versionados).

## Como rodar

O fluxo tem duas etapas.

**1. Ingestão (manual, uma vez por fonte).** Cada script lê de `data_raw/` e grava o `.rds`
limpo ao lado. Esses scripts **não** fazem parte do `targets`:

```r
source("data/snv/snv.R")
source("data/prf/prf.R")
source("data/focos/focos.R")
source("data/vdma/vdma.R")
```

**2. Pipeline (`targets`).** A partir da raiz do projeto, dentro do R:

```r
targets::tar_make()           # roda/atualiza todo o pipeline
targets::tar_visnetwork()     # inspeciona o DAG e o que está desatualizado
targets::tar_load(dataset)    # carrega um target na sessão (lista, um elemento por ano)
targets::tar_read(taxas)      # retorna um target sem vinculá-lo
```

Os mapas são gravados em `plots/` ao final.

## Passo a passo metodológico

### Parâmetros (targets de configuração)

| Parâmetro | Valor | Significado |
|-----------|-------|-------------|
| `anos` | `2020:2025` | Anos processados (cada um vira um elemento de lista via `pattern = map(anos)`) |
| `buffer_dist` | `500` | Raio do *buffer*, em metros, para contagem de focos |
| `crs_original` | `4326` | CRS de entrada (WGS84) dos pontos PRF/focos |
| `crs_conico` | `5880` | Policônica do Brasil — usada em **toda** a matemática de distância/área |

### 1. Ingestão e limpeza

Cada `data/<fonte>/<fonte>.R` lê o bruto e grava um `.rds`. Particularidades tratadas:

- **`prf.R`** — o separador decimal muda entre os anos (vírgula em 2020–2023, ponto em 2024). Para não corromper os valores, `km`/`latitude`/`longitude` são lidos como texto e convertidos manualmente para numérico.

- **`vdma.R`** — a aba de dados não está numa posição fixa entre os anos (escolhe-se sempre a aba que **não** é "Metadados"). O ano de **2021** chega no schema do PNCT: as colunas `VMDA_AB`/`VMDA_BA` são renomeadas para `VMDa_C`/`VMDa_D` e o código SRE é remapeado para `id_trecho_` por um *crosswalk* (`vl_codigo` → `id_trecho_`) extraído do SNV, agregando os sub-trechos pela **média** da VMDa.

- **`focos.R`** e **`snv.R`** — leitura direta dos arquivos brutos (CSV e shapefile).

### 2. Preparo por ano

- `prepare_snv` — reprojeta a malha SNV para a CRS cônica (5880).

- `prepare_prf` / `prepare_focos` — filtram a fonte para o ano, descartam coordenadas ausentes, convertem para pontos `sf` (a partir de lon/lat) e reprojetam para a cônica.

- `filter_vdma` — filtra a VDMA do ano e remove duplicatas exatas por `id_trecho_` (para não inflar as contagens no `left_join` posterior).

### 3. Junção espacial — a distinção central

A semântica do cruzamento espacial **difere por fonte**:

- **Focos → *buffer*** (`count_focos`): cria um *buffer* de `buffer_dist` (500 m) em torno de cada segmento e conta quantos focos o interceptam (`st_intersects`).

- **Sinistros → vizinho mais próximo** (`count_sinistros`): associa cada sinistro ao segmento mais próximo (`st_nearest_feature`) e conta por segmento.

### 4. Montagem do dataset (`build_dataset`)

Parte da malha SNV e agrega, por `id_trecho_`:

- `n_focos` (do *buffer*) e `n_sinistros` (do vizinho mais próximo) via `left_join` — segmentos sem focos/sinistros ficam `NA` e são convertidos para `0`;

- `fluxo = (VMDa_C + VMDa_D) × 365` — volume anual de tráfego (veículos/ano);

- `dist_m = st_length(geometry)` — comprimento do segmento (m).

Saída: **uma linha por segmento-ano** com `id_trecho_, ano, n_focos, n_sinistros, fluxo, dist_m`.

### 5. Cálculo das taxas (`calc_taxas`)

As contagens são normalizadas pela **exposição ao tráfego** (`fluxo × dist_m`, em veículo·metro):

```r
taxa_sinistros = n_sinistros / (fluxo * dist_m) * 1000 * 1e6
taxa_focos     = n_focos     / (fluxo * dist_m) * 1000 * 1e6
```

O fator `1000 × 1e6` (= 1e9) escala a taxa para *contagens por bilhão de veículo·metro*, tornando comparáveis segmentos com comprimentos e fluxos diferentes.

### 6. Mapas (`R/plot.R`)

- `prepare_br` — contorno do Brasil (estados dissolvidos via `geobr`), reprojetado para a cônica.

- `calc_limites` — intervalo global (min/máx) de cada variável **sobre todos os anos**, para que os mapas de uma mesma variável compartilhem a escala de cor e sejam comparáveis entre anos.

- `salvar_mapas` — gera **5 mapas por ano** (`fluxo`, `taxa_sinistros`, `taxa_focos`, `n_focos`, `n_sinistros`) em `plots/` (PNG, 7×5 in, 300 dpi; paleta *magma*; taxas em escala `log1p`).

## Dicionário do dataset

| Coluna | Unidade | Descrição |
|--------|---------|-----------|
| `id_trecho_` | — | Identificador do trecho SNV (chave canônica de junção) |
| `ano` | ano | Ano de referência (2020–2025) |
| `n_focos` | contagem | Focos de queimada dentro do *buffer* de 500 m do segmento |
| `n_sinistros` | contagem | Sinistros de trânsito associados ao segmento (vizinho mais próximo) |
| `fluxo` | veículos/ano | `(VMDa_C + VMDa_D) × 365` |
| `dist_m` | metros | Comprimento do segmento |
| `taxa_sinistros` | por 1e9 veículo·m | `n_sinistros / (fluxo × dist_m) × 1e9` |
| `taxa_focos` | por 1e9 veículo·m | `n_focos / (fluxo × dist_m) × 1e9` |
