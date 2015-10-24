#!/usr/bin/perl
use warnings;
use strict;

my $text; # сюда пишем текст
my $string; # сюда пишем уравнение
my $read_eq = 0; # признак чтения уравнения

my $full_output; #окончательная строка

$full_output = '\nonstopmode
\documentclass [a4paper] {article}
\usepackage[T1]{fontenc}
\usepackage [utf8] {inputenc}
\usepackage{amsmath,amsfonts,amssymb,wasysym,latexsym,marvosym,txfonts}
\usepackage[pdftex]{color}
\usepackage[T2A]{fontenc}
\usepackage [english, russian] {babel}
\usepackage[left=1cm,right=1cm,
    top=1cm,bottom=2cm,bindingoffset=0cm]{geometry}

\pagestyle{empty}
\begin{document}
\fontsize{12}{24}
\selectfont
\color{black}
\pagecolor{white}

';

while (<>) {

	if (/OUTPUT/) {
		$read_eq = 1; # читаем уравнение
		next;
	}

	if (/END/) {

$read_eq = 0; # закончили читать уравнение

####### ОБРАБОТКА  УРАВНЕНИЯ ########

$string =~ s/sgm_([A-Z]+?)([a-z]+?)\^([a-z0-9+-]+) x/\\sigma_{$1\\dot{$2}}^$3 /g; # все сигмы меняем
$string =~ s/_([a-z]):::([a-z0-9+-]+) x/\($2\)_{$1} /g; # все импульсы меняем

# после эпсилонов знак умножить убираем -- неудобный для чтения человеку
$string =~ s/e\^([A-Z]+),([A-Z]+) x/\\epsilon\^{$1,$2} /g; # все эпсилоны (с большими индексами) меняем
$string =~ s/e\_([a-z]+),([a-z]+) x/\\epsilon\_{\\dot{$1},\\dot{$2}} /g; # все эпсилоны (с маленькими индексами) меняем
# еще нижние индексы (от выражений типа dd DDDD dd, потом будем их сворачивать)
$string =~ s/e\_([A-Z]+),([A-Z]+) x/\\epsilon\_{$1,$2} /g; # все эпсилоны (с большими индексами) меняем
$string =~ s/e\^([a-z]+),([a-z]+) x/\\epsilon\^{\\dot{$1},\\dot{$2}} /g; # все эпсилоны (с маленькими индексами) меняем

$string =~ s/f(\d+?):::([a-z0-9+-]+)/\\bar{\\phi}_$1($2)/g; # все f поля меняем
$string =~ s/F(\d+?):::([a-z0-9+-]+)/\\phi_$1($2)/g; # все F поля меняем
$string =~ s/V(\d+?):::([a-z0-9+-]+)/V_$1($2)/g; # все F поля меняем

$string =~ s/D(\d+?)\_([A-Z]+)/D_{$1$2}/g; # все Ковариантные производные меняем (без черты)
$string =~ s/D(\d+?)\^([A-Z]+)/D\_{$1}^{$2}/g; # все Ковариантные производные меняем

$string =~ s/D(\d+?)\_([a-z]+)/\\bar{D}_{$1\\dot{$2}}/g; # все Ковариантные производные меняем (с чертой)
$string =~ s/D(\d+?)\^([a-z]+)/\\bar{D}_{$1}\^{\\dot{$2}}/g; # все Ковариантные производные меняем (с чертой)

#$string =~ s/eta\^([a-z])([a-z]) x/\\eta\^{$1$2}/g; # все метрические тензоры!

$string =~ s/krnck_([A-Z]+?)\^([A-Z]+?) x/\\delta_{$1}\^{$2}/g; # все кронекеры!
$string =~ s/krnck_([a-z]+?)\^([a-z]+?) x/\\delta_{\\dot{$1}}\^{\\dot{$2}}/g; # все кронекеры!


	# раскрываем скобки при умножении ~ +(10) и +(-10)
	$string =~ s/\+ \(([2-9]+)\) x/\+\\\\+ $1/g; # если знак внутри "+" 
	$string =~ s/\+ \(\-([2-9]+)\) x/\-\\\\- $1/g; # если знак внутри "-"
#для того, чтобы двузначные и более числа тоже раскрывались. Выше же для игнорирования (1)
#да, вот такие вот костыли, а что поделать?
	$string =~ s/\+ \(([1-9][0-9]+)\) x/\+\\\\+ $1/g; # если знак внутри "+" 
	$string =~ s/\+ \(\-([1-9][0-9]+)\) x/\-\\\\- $1/g; # если знак внутри "-"

	$string =~ s/\+ \((1+)\) x/\+\\\\+/g; # если знак внутри "+" 
	$string =~ s/\+ \(\-(1+)\) x/\-\\\\-/g; # если знак внутри "-"

	$string =~ s/\+ \((0)\) x/\+\\\\+ 0 x/g; # если 0 
	
	$string =~ s/\(1\) x//g; # избавиться от единичек
	$string =~ s/\(-1\) x/-/g; # избавиться от единичек

	$string =~ s/\(([0-9]+)\) x/$1/g; # избавиться от скобочек
	$string =~ s/\(-([0-9]+)\) x/-$1/g; # избавиться от скобочек


$string =~ s/ x / \\times /g; # все знаки умножить меняем


$string =~ s/dd(\d+)_(\d+):::([a-z0-9+-]+)/\\delta_{$1$2}[$3]/g; # все дельта-функции меняем

$string =~ s/([a-z])(\d+)/$1_{$2}/g; # все индексы лоренца опускаем

$string =~ s/=/=\\\\=/g; # знак "=", перенос

# Обрамление уравнения 

$string = '
\begin{math} 
'.$string.'\end{math}
\\\\';

$full_output .= $string; # добавляем уравнение к общему выводу

$string = undef; # очищаем строку для следующего уравнения

next; # чтобы *** END *** не вошло

	}

	if ($read_eq == 1) {
		chomp;
		$string .= $_;
	} else {
		$full_output  .= $_;
	}


}

$full_output .= '
\end{document}';



print $full_output;
