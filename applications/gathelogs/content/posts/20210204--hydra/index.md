---
title: "Structured Configsを使ったHydraでの型付"
# date: 2021-02-04T00:45:26Z
date: 2021-02-04T00:45:26Z
draft: false
categories: [ML Tools]

tags:
- Mypy
- Python
- Hydra
# menu: footer # Optional, add page to a menu. Options: main, side, footer

thumbnail:
    src: "header/20210204--hydra.png" # Thumbnail image
    visibility:
        - list
        - post
# lead: "" # Lead text
comments: true
authorbox: true # Enable authorbox for specific page
pager: true # Enable pager navigation (prev/next) for specific page
toc: true # Enable Table of Contents for specific page
mathjax: true # Enable MathJax for specific page
sidebar: "right" # Enable sidebar (on the right side) per page
widgets: # Enable sidebar widgets in given order per page
  - "recent"
  - "categories"
  - "taglist"
  - "social"
---

[Hydra](https://github.com/facebookresearch/hydra) は [Facebook Open Source (現在は Meta Open Source)](https://opensource.facebook.com/) 
が公開している設定管理のためのフレームワークです。
YAML 形式で設定ファイルを**階層的に定義**することが可能で、複数のパラメータに渡ってコードを実行する 
[Multi-run](https://hydra.cc/docs/1.0/tutorials/basic/running_your_app/multi-run/) や
クラスや関数の[動的な呼び出し](https://hydra.cc/docs/1.0/patterns/instantiate_objects/overview/)など便利な機能が多数実装されています。

私も2020年の頭に[やむやむさんのブログ投稿](https://ymym3412.hatenablog.com/entry/2020/02/09/034644)などを参考にさせて頂きながら導入し、
それ以降ずっと実験用のコードに使用していました。
しかし、[PFNの技術ブログの投稿](https://tech.preferred.jp/en/blog/working-with-configuration-in-python/)などでも良くないとして指摘されている、
**型付けされていない設定変数をそのまま使用している状態**になっており、
この点は改善したいと思いながら最近までそのまま放置していました。

ところが、最近 Hydra の document を読み直していると、version 1.0 で追加された機能である 
[Structured Configs](https://hydra.cc/docs/1.0/tutorials/structured_config/intro) 
**を使用すれば型チェックが可能**との記載を発見し、
自分のコードに組み込むために色々試してみました。今回の記事はその際に勉強したことの一部です。

※本記事の内容は **Hydra version 1.0** に基づいて記載されています。
1.1以降のバージョンで試される方は互換性に注意して下さい。

## Structured Configs とは

Structured Configs は dataclass 等を使って設定変数の**構造**と**型**が定義されたオブジェクト
（[OmegaConf](https://github.com/omry/omegaconf) のオブジェクト）です。
OmegaConf とは Hydra が低レイヤーで使用しているフレームワークであり、Hydra の階層的な設定ファイルの定義は OmegaConf の機能によって実現されています。
Structured Configs の機能も OmegaConf 側で実装されたものが version 1.0 から Hydra 経由でも使用可能になりました。

Structured Configs を使用することで、 次のようなことが Hydra で可能になります。

- 設定変数の**実行時の型チェック**
- [mypy](https://github.com/python/mypy)などの静的型チェッカーを用いた**静的な型チェック**

これらによって、**設定変数の上書きが適切な型で行われているかの実行時の確認**や、
**読み込まれたパラメータが適切に使用されているかの静的な確認**が可能になるというメリットがあります。

## Structured Configs を使用しない場合の問題点

ここでは、まず Structured Configs を使用しない場合に生じうる問題点を、単純な具体例を用いて確認します。
次の2つの設定変数を Hydraを使用して関数 `train` に渡す状況を考えます。

- `exp_name`: 実験の名称（str 型）
- `epochs`: エポック数（int 型）

YAML に記載した設定変数を読み込んで `train` に渡すコードは、以下のようになります。

{{< code-title lang="yaml" title="config_01.yaml" >}}
exp_name: "standard_train"
epochs: 90
{{< / code-title >}}

{{< code-title lang="text" title="ディレクトリ構成" >}}
working_directory
├── config_01.yaml
└── train_01.py
{{< / code-title >}}

{{< code-title lang="python" title="train_01.py" >}}
import hydra
from omegaconf import DictConfig, OmegaConf

@hydra.main(config_name="config_01")  # yamlファイルから設定変数を読み込んでいる
def train(cfg: DictConfig) -> None:
    print(OmegaConf.to_yaml(cfg))  # cfgをyaml形式に変換して表示

if __name__ == "__main__":
    train()
{{< / code-title >}}

ターミナルから `train_01.py` を実行すると YAML ファイルから読み込まれた設定変数が次のように表示されます。また、これらの設定変数は実行時に上書きすることも可能です。

{{< code-title lang="text" title="ターミナル（train_01.pyを実行）" >}}
$ python train_01.py
exp_name: standard_train
epochs: 90

$ python train_01.py exp_name=adversarial_train epochs=120
exp_name: adversarial_train
epochs: 120
{{< / code-title >}}

しかし、`config_01.yaml` や `train_01.py` には `exp_name` や `epochs` の**型に関する情報はどこにも明示されていません**。
従って、次のように `epochs` を**誤って文字列で上書き**してしまった場合でも、**実行時にその場で検出することが出来ません**。

{{< code-title lang="text" title="ターミナル（epochs を文字列で上書きしてtrain_01.pyを実行）" >}}
$ python train_01.py epochs=hoge
exp_name: standard_train
epochs: hoge
{{< / code-title >}}

また、次のように `train` 関数内で誤って str 型の `exp_name` と int 型の `epochs` の算術和を計算しようとした場合に、
型情報が無いために mypy などの**静的型チェッカーで型違反を検出することが出来ません**。

{{< code-title lang="python" title="train_01_dash.py" >}}
import hydra
from omegaconf import DictConfig, OmegaConf

@hydra.main(config_name="config_01")
def train(cfg: DictConfig) -> None:
    print(OmegaConf.to_yaml(cfg))
    fuga = cfg.exp_name + epochs  # 誤ってstr型とint型の算術和を計算しようとしている

if __name__ == "__main__":
    train()
{{< / code-title >}}

{{< code-title lang="text" title="ターミナル（train_01_dash.pyに静的型チェックを適用）" >}}
$ mypy train_01_dash.py
Success: no issues found in 1 source file
{{< / code-title >}}

繰り返しになりますが、Structured Configs を使用することで上述の問題点を解決することが出来ます。
Structured Configs の使い方には、大きく分けて次の2つの方法があるため、それぞれ確認していきます。

- YAML ファイルの代わりに使用する方法
- 設定を読み込む YAML ファイルのスキーマとして使用する方法

## YAML ファイルの代わりとして Structured Configs を使用

ここでは、YAML ファイルを置き換える形で Structured Configs を使用する場合を考えます。
前述の `config_01.yaml` と `train_01.py` を Structured Configs を使って書き換えたものは次のようになります。

{{< code-title lang="text" title="ディレクトリ構成" >}}
working_directory
└── train_02.py
{{< / code-title >}}

{{< code-title lang="python" title="train_02.py" >}}
import hydra
from dataclasses import dataclass
from hydra.core.config_store import ConfigStore
from omegaconf import OmegaConf

@dataclass
class TrainConfig:
  exp_name: str = "standard_train"  # exp_nameをstr型として定義
  epochs: int = 90  # epochsをint型として定義

cs = ConfigStore.instance()
cs.store(name="config", node=TrainConfig)  # "config"という名前でTrainConfigを登録

@hydra.main(config_name="config")  # 登録した"config"を使用
def train(cfg: TrainConfig) -> None:
    print(OmegaConf.to_yaml(cfg))

if __name__ == "__main__":
    train()
{{< / code-title >}}

変更点を順に確認します。まず、dataclass として TrainConfig クラスを定義しています。
この TrainConfig クラス内で設定引数の**型**と**デフォルト値**を定義しています。

{{< highlight python "linenos=false" >}}
@dataclass
class TrainConfig:
  exp_name: str = "standard_train"  # exp_nameをstr型として定義
  epochs: int = 90  # epochsをint型として定義
{{< / highlight >}}

次に、ConfigStore クラスの `store` メソッドを用いて、TrainConfig クラスを`"config"`という名前で登録しています。

{{< highlight python "linenos=false" >}}
cs = ConfigStore.instance()
cs.store(name="config", node=TrainConfig)  # "config"という名前でTrainConfigを登録
{{< / highlight >}}

最後に、登録した`"config"`という名前の設定を Hydra を経由して `train` 関数に渡しています。

{{< highlight python "linenos=false" >}}
@hydra.main(config_name="config")  # 登録した"config"を使用
def train(cfg: TrainConfig) -> None:
    print(OmegaConf.to_yaml(cfg))
{{< / highlight >}}

ターミナルから `train_02.py` を実行すると `train_01.py` の実行時と同じように設定変数の値が表示され、TrainConfig で定義したデフォルト値が読み込まれていることが確認出来ます。
また、`train_01.py` のときと同様に、これらの設定変数は実行時に上書きすることも可能です。

{{< code-title lang="text" title="ターミナル（train_02.pyを実行）" >}}
$ python train_02.py
exp_name: standard_train
epochs: 90

$ python train_02.py exp_name=adversarial_train epochs=120
exp_name: adversarial_train
epochs: 120
{{< / code-title >}}

ここまでは、YAML ファイルを読み込んだ場合と何ら変わりないですが、ここからが Structured Configs を使用したことによるメリットの部分です。

`train_01.py` のときと同様に `epochs` を誤って文字列で上書きしてしまった場合を試してみます。

{{< code-title lang="text" title="ターミナル（epochs を文字列で上書きしてtrain_02.pyを実行）" >}}
$ python train_02.py epochs=hoge
Error merging override epochs=hoge
Value 'hoge' could not be converted to Integer
    full_key: epochs
    reference_type=Optional[TrainConfig]
    object_type=TrainConfig
Set the environment variable HYDRA_FULL_ERROR=1 for a complete stack trace.
{{< / code-title >}}

Structured Configs を使用したことによって、今回は定義された型に変換出来ない値で置き換えが行われたことを表すエラー
（`Value 'hoge' could not be converted to Integer`）が出力されています。

また、`train` 関数内で誤って str 型の `exp_name` と int 型の `epochs` の算術和を計算しようとした場合に対して静的型チェックを行ってみます。

{{< code-title lang="python" title="train_02_dash.py" >}}
import hydra
from dataclasses import dataclass
from hydra.core.config_store import ConfigStore
from omegaconf import OmegaConf

@dataclass
class TrainConfig:
  exp_name: str = "standard_train"
  epochs: int = 90

cs = ConfigStore.instance()
cs.store(name="config", node=TrainConfig)

@hydra.main(config_name="config")
def train(cfg: TrainConfig) -> None:
    print(OmegaConf.to_yaml(cfg))
    fuga = cfg.exp_name + epochs  # 誤ってstr型とint型の算術和を計算しようとしている

if __name__ == "__main__":
    train()
{{< / code-title >}}

{{< code-title lang="text" title="ターミナル（train_02_dash.pyに静的型チェックを適用）" >}}
$ mypy train_02_dash.py
train_04.py:17: error: Unsupported operand types for + ("int" and "str")
Found 1 error in 1 file (checked 1 source file)
{{< / code-title >}}

こちらも Structured Configs を使用したことによって型違反が検出されるようになっています。

## YAML ファイルのスキーマとして使用

ここでは、Structured Configs を YAML ファイルのスキーマとして使用する場合を考えます。
これはConfigStore に YAML ファイルの名前と同名の設定を追加することで実現出来ます。

`train_03.py` では YAML ファイルと同名の `"config_03"` という名前で TrainConfig を ConfigStore に登録することで、
TrainConfig クラスが `config_03.yaml` のスキーマとして使用されます。
（別名の YAML ファイルに対してスキーマを設定することも可能です。
詳細は[こちら](https://hydra.cc/docs/1.0/tutorials/structured_config/dynamic_schema/)の Hydra のTutorial をご確認下さい。）

{{< code-title lang="yaml" title="config_03.yaml" >}}
exp_name: "adversarial_train"
epochs: 120
{{< / code-title >}}

{{< code-title lang="text" title="ディレクトリ構成" >}}
working_directory
├── config_03.yaml
└── train_03.py
{{< / code-title >}}

{{< code-title lang="python" title="train_03.py" >}}
import hydra
from dataclasses import dataclass
from hydra.core.config_store import ConfigStore
from omegaconf import OmegaConf

@dataclass
class TrainConfig:
  exp_name: str = "standard_train"
  epochs: int = 90

cs = ConfigStore.instance()
cs.store(name="config_03", node=TrainConfig)  # yamlファイルと同じ名前でTrainConfigを登録

@hydra.main(config_name="config_03")  # 登録した"config_03"を使用
def train(cfg: TrainConfig) -> None:
    print(OmegaConf.to_yaml(cfg))

if __name__ == "__main__":
    train()
{{< / code-title >}}

{{< code-title lang="text" title="ターミナル（train_03.pyを実行）" >}}
$ python train_03.py
exp_name: adversarial_train
epochs: 120
{{< / code-title >}}

実行結果から `python train_03.py` を実行した際は `config_03.yaml` から読み込まれた値が使用されていることが分かります。
また、TrainConfig クラスをスキーマとして使用することで、以下の例ように**YAML ファイルの設定変数に誤って異なる型の値を指定**した場合や、
**誤って設定変数を追加で記載**してしまった場合なども検出することが出来ます。

{{< code-title lang="yaml" title="config_03.yaml（epochsに文字列を指定）" >}}
exp_name: "adversarial_train"
epochs: "hogehoge"
{{< / code-title >}}

{{< code-title lang="text" title="ターミナル（train_03.pyを実行）" >}}
$ python train_03.py
Error merging 'config_03' with schema
Value 'hogehoge' could not be converted to Integer
    full_key: epochs
    reference_type=Optional[Dict[Union[str, Enum], Any]]
    object_type=TrainConfig
Set the environment variable HYDRA_FULL_ERROR=1 for a complete stack trace.
{{< / code-title >}}

`train_03.py` では TrainConfig 内で設定変数のデフォルト値を指定していますが、
スキーマ側で設定変数の**デフォルト値を指定したくない場合**は `omegaconf.MISSING` という値を用いることが出来ます。

{{< highlight python "linenos=false" >}}
from omegaconf import MISSING

@dataclass
class TrainConfig:
  exp_name: str = MISSING
  epochs: int = MISSING
{{< / highlight >}}

## まとめ

今回の記事では、Hydra に version 1.0 で追加された機能である Structured Configs を用いることで、
Hydra で読み込んだ設定変数に対して、実行時の型チェックや、静的型チェックを適用する方法を紹介しました。

既に YAML ファイルを使用した Hydra での設定管理を行っている方は、実装としては dataclass を定義してYAML ファイルと対応させるだけで、
少ない労力で型付けのメリットを得られることが確認出来たと思います。

Hydra ユーザーの方でまだ Structured Configs を使用していない場合は、これを機に導入をしてみてはいかがでしょうか。