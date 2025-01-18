#lang punct

---
a: sd a a   
title: This is a normal string value
f: b a
fav-number: '2+ 3i
other- numbers : '(7 #b101 2/3)
draft?: '#t
case-insenstive-symbol-with-space: '#ci HOB| |NOB
fruit-ratings: '#hash((apple . 4) (pear . 5) (grape . 3))
name-regex: '#rx"(Bob|Alice)"
boxed: '#:17
vector: '#[23 22 9811]
nemesis-struct: '#s(prefab:clown "Binky" "pie")
commented-number: '#| this will be equalto fourteen |# 14 
non-cyclic-graph: '(#1=42 #1# #1#)
now you're just showing off: '#lang scribble/manual There are @+[3 4] words in this anonymous module
---

hello