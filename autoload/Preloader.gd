## autoload/Preloader.gd
## 放在所有 autoload 最前面
## 目的：在其他 autoload 解析前，强制注册所有 class_name 类型
## 这样 GameState / EventBus / TimeManager 里的 CatData / GameConstants 等就能正确解析
extends Node

const _GameConstants  := preload("res://data/constants.gd")
const _CatData        := preload("res://resources/CatData.gd")
const _CardData       := preload("res://resources/CardData.gd")
const _CatFactory     := preload("res://data/cat_factory.gd")
const _BreedingSystem := preload("res://scenes/camp/BreedingSystem.gd")
const _ExpeditionSys  := preload("res://scenes/expedition/ExpeditionSystem.gd")
