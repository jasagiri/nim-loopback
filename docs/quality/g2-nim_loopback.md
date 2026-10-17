# G2 (変異検査): `src/nim_loopback.nim`

- 測定日: 2026-10-17
- 道具: nim-muter 0.2.10
- ジョブ: `tests/mutation/nim_loopback.json` (リポジトリ直下で `../nim-muter/bin/nim-muter run --config tests/mutation/nim_loopback.json`)
- 対象テスト: `tests/test_loopback.nim` (E テストのみ。公開 proc だけを呼ぶ)

## 結果

| | killed | survived | timeout | compileError | 計 |
|---|---:|---:|---:|---:|---:|
| 追加前 | 166 | 38 | 0 | 22 | 226 |
| 追加後 | 185 | 19 | 0 | 22 | 226 |

compileError 22 件は変異後のコードがコンパイルできなかったもので、テストの穴ではない。

## 生き残った変異と理由

残り 19 件はすべて、どんな入力でも公開 proc の戻り値が変わらないことを確認した同値変異か、冗長な検査である。timeout は 0 件。

「ゼロ初期化」とは次の事実を指す。`ipv6Groups` の呼び出し元は `isLoopbackIpv6` だけで、`var g: array[8, int]` を宣言した直後 (全要素 0) に渡す。`ipv6Groups` が `groups` を書かずに返ると `g` は全 0 (`::`) のままで、`isLoopbackIpv6` は `::1` でも `::ffff:127.x` でもないので false を返す。

| 行 | 変異子 | 元 → 変更後 | 理由 |
|---:|---|---|---|
| 28 | CVR | `text.len > 3` → `> 4` | 4 桁の文字列は、先頭が 0 なら 29 行目、数字以外を含めば 32 行目、それ以外は 1000 以上で 34 行目の `> 255` により、いずれも -1 になる。長さの検査は早期打ち切りで、結果に影響しない。 |
| 61 | CVR | `text.len == 0` → `== 1` | 空文字列は 79 行目の `left.len != 8` で false になる。IPv6 は最短でも `::` の 2 文字なので、1 文字の入力は有効になり得ず、`read` が 8 グループを返さず false になる。 |
| 61 | LOR | `text.len == 0 or '%' in text` → `and` | `%` は 16 進数字でも十進数字でもなく、`hexGroup` (47〜56 行目) と `decimalOctet` (32 行目) が必ず -1 を返す。`:` と `.` 以外のすべての文字がどちらかの解析を通るので、`%` を含む入力は 61 行目の検査がなくても false になる。空文字列は上の行の理由で false になる。 |
| 61 | LOR | `a or b or c` → `(a or b) and c` | `::` が 2 回出る入力は、最初の `::` の右側に空のグループ (`::` の 2 個目、または `:::` の 3 つ目の `:`) が残り、`hexGroup("")` が -1 を返して false になる。`a`、`b` は上の 2 行の理由で同じ。 |
| 61 | CVR | `count("::") > 1` → `> 2` | 上の行と同じ。`::` が 2 回出る入力は 61 行目の検査なしでも false になる。 |
| 61 | RVR | `return false` → `<return default>` | `bool` の既定値は false で、元のコードと同じ。 |
| 61 | BLR | `return false` → `return true` | ゼロ初期化 (表の前の説明) により、`groups` が書かれずに true で返っても `isLoopbackIpv6` は false を返す。 |
| 70 | CVR | `decimalOctet(octets[2]) * 256` → `* 257` | `g[7]` が参照されるのは `g[7] == 1` だけ。`o2*256+o3 == 1` と `o2*257+o3 == 1` はどちらも `o2=0, o3=1` (各 0〜255) のときだけ成り立つので、`g[7] == 1` かどうかは変わらない。`g[7]` の別の値は 94 行目の `::ffff:` 形で使われない。 |
| 79 | RVR | `return false` → `<return default>` | `bool` の既定値は false で、元のコードと同じ。 |
| 79 | BLR | `return false` → `return true` | ゼロ初期化により、`groups` が書かれずに true で返っても `isLoopbackIpv6` は false を返す。 |
| 81 | RVR | `return false` → `<return default>` | 同上。 |
| 81 | BLR | `return false` → `return true` | 同上 (ゼロ初期化)。 |
| 82 | RVR | `return false` → `<return default>` | 同上。 |
| 82 | BLR | `return false` → `return true` | 同上 (ゼロ初期化)。 |
| 83 | CVR | `for i in 0 ..< 8: groups[i] = 0` の `0` → `1` | `groups[0]` を 0 にしなくなるが、呼び出し元はゼロ初期化した配列を渡す (表の前の説明)。初期化の 83 行目そのものが、このコードでは冗長である。 |
| 99 | ROR | `host.len >= 2` → `> 2` | 変わるのは長さ 2 の入力で、`[` で始まり `]` で終わる 2 文字は `[]` だけ。元は `isLoopbackIpv6("")` で false、変異後は 101 行目以降を通って `isLoopbackIpv6("[]")` になり、`hexGroup("[]")` が -1 で false。どちらも false。 |
| 99 | CVR | `host.len >= 2` → `>= 3` | 上の行と同じ (`[]` のみが違い、どちらも false)。 |
| 112 | ROR | `close < 0` → `<= 0` | 110 行目で `authority` は `[` で始まるので、`]` の位置 `close` は 1 以上になる。`close == 0` は起こらない。 |
| 112 | CVR | `close < 0` → `< 1` | 上の行と同じ。`close == 0` は起こらない。 |

## 追加したテスト (`tests/test_loopback.nim`)

| テスト名 (冒頭) | 殺した変異 |
|---|---|
| LB-02 Given an IPv4-mapped address When asked Then only 127.0.0.0/8 is loopback, whatever the second number | 69 行目 CVR `256` → `257` (`::ffff:127.255.0.1`) |
| LB-02 Given ::1 written with an IPv4 tail When asked Then loopback; any other tail, not | 67 行目 ROR `< 0` → `<= 0`、CVR `0` → `1` (`::0.0.0.1`)、69 行目 CVR `1` → `2`、70 行目 CVR `2` → `3`、AOR `+` → `-` |
| LB-02 Given an IPv4 tail that is not four plain decimal numbers When asked Then not, even after groups that would be loopback | 42 行目 RVR / CVR (`::ffff:127.0.0.256`)、67 行目 BLR (`::1:127.0.0.256`)、RVR |
| LB-02 Given a group of five hex digits When asked Then not, even if its value would make a loopback address | 47 行目 CVR `4` → `5` (`::00001`) |
| LB-02 Given groups in the last two places other than 0:1 or ffff:127.x When asked Then not | 93 行目 CVR `5` → `6`、LOR `and` → `or` (`::ffff:0:1`、`::2:1`) |
| LB-02 Given :: standing for one group, or for none When asked Then one group is read, none is not | 82 行目 AOR `+` → `-`、ROR `>` → `>=`、CVR `7` → `8` (`0:0:0:0:0:0::1` と `0:0:0:0:0:0:0::1`) |
| LB-04 (既存の loopback テストにポート `8`、`0` を追加) | 109 行目 CVR `0` → `1` (`127.0.0.1:8`) |
| LB-04 Given a bracket that is never closed When asked Then not, whatever follows | 112 行目 BLR `false` → `true` (`[::1`) |
