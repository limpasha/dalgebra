#!/usr/bin/perl
use warnings;
use strict;

			###################################
			#   Секция объявления пременных	  #
			###################################

my @summands; # основной массив, элементы - слагаемые

my @coeff; # числовой коэффициент каждого слагаемого

# создаем основную сложную структуру данных
#
# программно:  $summands[] - ссылка на массив сомножителей для одного слагаемого
#			[][] - ссылка на массив сомножителя (умножение x)
#			[][][0] - строка с самим типом сомножителя: dd, f, F, V
#			[][][1] - ссылка на массив dpart (массив can be непуст для dd, f, F, V)
#			[][][1][] - элемент массива dpart
#
# качественно: $summands[номер слагаемого][номер сомножителя x][0=тип сомножителя, 1=его dpart]
#							       [элемент его dpart]

@summands = ( [ [ 'type' , [] ] ]
	);

@coeff =  ();

			###################################
			#  Секция ввода начальных данных  #
			###################################


# Далее заполняем нашу структуру первым (нулевым), вторым и третьим слагаемым 

$coeff[0] = 1;
$summands[0][0][0] = 'F1:::-p';
@{ $summands[0][0][1] } = ();

$summands[0][1][0] = 'dd1_2:::p+k1';
@{ $summands[0][1][1] } = qw ( D1^A D1_A D2_a D2^a );

$summands[0][2][0] = 'dd2_1:::p+k1+k2';
@{ $summands[0][2][1] } = qw ( D2^M D2_M D1_c D1^c );

$summands[0][3][0] = 'f2:::p';
@{ $summands[0][3][1] } = ();

#$summands[0][4][0] = 'sgm_Ln^b';
#@{ $summands[0][4][1] } = ();

#$coeff[1] = -3;
#$summands[1][0][0] = '_n:::q2';
#@{ $summands[1][0][1] } = ();

#$coeff[2] = -18;
#$summands[2][0][0] = 'dd4_3:::q2+p2';
#@{ $summands[2][0][1] } = qw (D4^A D3_A);


			#################################
			#	Подпрограммы		#
			#################################


# Функция для выравнивания выражения с дельтой Дирака по тета-индексу
# 3 аргумента = (ссылка на массив factor, ссылка на массив coeff, номер слагаемого)
# Результат записывает по переданной ссылке в тот же массив
# Пример вызова функции: &index_align($summands[1][0], $summands[0], 1);

sub index_align {
	my $array_ref = shift; # первый аргумент - cчитываем ссылку на массив = (type, dpart)
	my $coeff = shift; # второй аргумент - ссылка на массив multiplicands, нам нужен только [number]
	my $number = shift; # третий аргумент - номер слагаемого=индекс массива @coeff

	my ($type, $dpart) = @$array_ref; # первый аргумент массива [0]- скаляр dd
					 #второй аргумент массива [1] - ссылка на массив dpart

	my @dpart_new = (); # новый массив, который будем формировать

	my $i; # счетчик

	# тут распарсим выражение для dd скаляра на 2 индекса и сравним их	

	my ($j, $k) = (0,0); #объявим пару новых переменных для индексов дельта-функции

	if ($type =~ /dd(\d+)_(\d+)/){
		($j, $k) = ($1, $2); # в j и k сохраняем считанные индексы дельта-функции
	}

	# j должна быть в нашей подпрограмме меньше k, если не так - меняем местами

	if ($j > $k){
		($j, $k)=($k, $j);
	}
	
	# разыменуем сначала в for ссылку на массив, присвоим ее $i в скалярном контексте,
	# чтобы получить число элементов массива и вычтем 1, чтобы получить индекс послед. эл-та

	for ($i = @$dpart-1; $i >= 0 ; $i-- ) { # идем от конца массива справа налево
		if ($dpart->[$i] =~ /D$k[\^_]/) { # проверяем наличие индекса k (большего j)
			$dpart->[$i] =~ s/D$k/D$j/; # заменяем индекс k на j
			push (@dpart_new, $dpart->[$i]); # добавляем в конец нового массива
			$coeff->[$number] *= (-1)**(@$dpart - $i); # степень (-1) считаем и пишем коэф.
		}
		else {
			unshift (@dpart_new, $dpart->[$i]); # добавляем в начало нового массива
		}
	}
	
	@{$dpart} = @dpart_new; # записываем в переданный массив по сслыке новый выровненный по тета-индексу массив

}


# Функция для удаления элемента из массива и сдвига всех его элементов влево, тем самым длина
# массива уменьшается на один элемент
# аргументы -- (ссылка на массив, индекс элемента)
# пример вызова &del_array_element (\@array, 3)

sub del_array_element {

	my $i; # счетчик

	# начинаем с данного i-ого элемента, копируем туда значение i+1 - ого элемента 

	for ($i = $_[1]; $i<= @{$_[0]} - 1; $i++) {
		@{$_[0]}[$i] = @{$_[0]}[$i+1];
	}
	
	pop @{$_[0]};
}


# Функция, отслеживающая наличие произведения трех ковариантных производных (с чертой или без)
# и при нахождении -- сообщающая об этом
# аргумент -- ссылка на массив dpart
# пример вызова: &detect_D_cubed (\@array);

sub detect_D_cubed {

	my @detect = (); # будем записывать сюда признак ковариантной производной: с чертой/без

	# разыменовываем ссылку на массив (переданную в аргумент функции)
	# обращаем массив и таким образом идем от конца dpart-массива к началу

	foreach (reverse @{$_[0]}) {

		if ($_ =~ /D(\d+)[\^_][A-Z]/) {	# если простая ковариантная производная: добавляем в начало массива 0
			unshift (@detect, 0);
		} else {
			unshift (@detect, 1); # если сопряженная: добавляем 1
		}
	
	}

	# проверяем совпадение минимум трех стоящих рядом признаков

	if (join ('',@detect) =~ /(.)\1\1/){
		return 1;
	} else {
		return 0;
	}
}

# Функция вывода текущего состояния всей структуры данных
# вызывается без аргументов

sub show_state {

	my $i = 0;
	my $string = '';

	$string .= "\n ********** OUTPUT ********* \n";
	
	# идем по каждому слагаемому

	foreach (@summands) {

		$string .= "+ \($coeff[$i]\) x "; # сначала выводим коэффициент-число (со знаком)

		foreach (@{$_}) {

			$string .= "@{$_->[1]} "; # тут выводим dpart
			$string .= "$_->[0] x " ; # тут выводим сам сомножитель (type)
		}

		$i++;
	}
	
	$string =~ s/  / /g; # Убираем двойные пробелы (оставленные от нулевой dpart при выводе)
	$string =~ s/x ([+-])/$1/g; # избавляемся от знаков "умножить" перед + или - --остатки
	
	# раскрываем скобки при умножении ~ -(+10)
#	$string =~ s/([+-]) \($1?([0-9]+)\)/\+ $2/g; # если знаки совпадают -(-1) или +(+1)
#	$string =~ s/([+-]) \([^$1]?([0-9]+)\)/\- $2/g; # если знаки разные +(-1) или -(+1))


	$string =~ s/ 1 x //g; # избавляемся от "умножить на 1"
	$string =~ s/ x $//g; # избавляемся от значка "умножить" в самом конце строки -- остатки
	$string =~ s/\n\+/\n/g; # избавляемся от знака "плюс" в самом начале строки

	$string .= "\n ************ END ********* \n";
}

# Функция возвращает список используемых индексов в слагаемом
# аргумент - номер слагаемого

sub indices_used {
	my $number = shift; # считаем сюда номер слагаемого
	my @list = (); # здесь будем формировать список индексов

	# идем по всем сомножителям и вытаскиваем индекс, записывая его в конец массива @list	
	
	foreach (@{$summands[$number]}) {

		foreach (@{$_->[1]}) { # тут выводим dpart

			if (/D(?:\d+)[\^_](.)/) {	
				push (@list, $1);
			}
		}
	}

	@list = sort @list; 
	
	# избавляемся от повторений в массиве @list (чей-то алгоритм)

	my %seen = ();
	my @uniq =();

	foreach (@list) {
		unless ($seen{$_}) {# Если мы попали сюда, значит, элемент не встречался ранее
			$seen{$_} = 1;
			push(@uniq, $_);
		}
	}

	@uniq; 
}

# Функция возвращает список используемых лоренц-индексов в слагаемом (ищем их в _n:::p и sgm_Ab^n)
# Лоренц-индексы будут только [a-z]
# аргумент - номер слагаемого

sub lorentz_indices_used {
	my $number = shift; # считаем сюда номер слагаемого
	my @list = (); # здесь будем формировать список индексов

	# идем по всем сомножителям и вытаскиваем индекс, записывая его в конец массива @list	
	
	foreach (@{$summands[$number]}) {

		if ($_->[0] =~ /^_(.)/) {	# тут выводим type, ищем в импульсах _n:::p
			push (@list, $1);
		}
		if ($_->[0] =~ /sgm_..\^(.)/) {	# тут выводим type, ищем в сигмах
			push (@list, $1);
		}
	}

	@list = sort @list; 
	
	# избавляемся от повторений в массиве @list (чей-то алгоритм)

	my %seen = ();
	my @uniq =();

	foreach (@list) {
		unless ($seen{$_}) {# Если мы попали сюда, значит, элемент не встречался ранее
			$seen{$_} = 1;
			push(@uniq, $_);
		}
	}

	@uniq; 
}

# Функция выискивания в первом массиве букв, которых нет во вторм массиве, возврат такой буквы
# первой по алфавиту, затем добавление этой буквы во второй массив
# аргументы = (ссылка на 1-ый массив, ссылка на 2-ой массив)

sub find_free_index {
	my ($one, $two) = @_; # получаем ссылки на массивы
	my ($first, $second); # счетчики

	my $fit; # совпадение для каждого элемента @{$one}	

	foreach $first (@{$one}) {
		$fit = 0;
		foreach $second (@{$two}){
			if ($first eq $second){
				$fit++;			
			}	
		}
		if ($fit == 0) {
			push (@{$two}, $first);
			return $first;
		}
	}
}

# Функция для опускания всех индексов
# в качестве аргумента передаются: (ссылка на массив factor, номер слагаемого)
# ЗАМЕЧАНИЕ: КОЛИЧЕСТВО СОМНОЖИТЕЛЕЙ МЕНЯЕТСЯ ПОСЛЕ ВЫПОЛНЕНИЯ, ИБО ВПЕРЕД ВСТАВЛЯЮТСЯ ЭПСИЛОНЫ
# пример вызова: &lower_index($summands[2][0],2). Первое число в [] и последний аргумент - всегда одинаковы!

sub lower_index {
	my $array_ref = shift; # первый аргумент - cчитываем ссылку на массив = (type, dpart)
	my $number = shift; # второй аргумент - номер слагаемого=индекс массива @coeff

	my $dpart = $array_ref->[1]; #второй аргумент массива [1] - ссылка на массив dpart
	my @indices = &indices_used($number); #список всех используемых индексов

	my @possible_indices_h = qw (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z);
	my @possible_indices_l = qw (a b c d e f g h i j k l m n o p q r s t u v w x y z);

	my $index;	

	# Перебираем элементы массива dpart, ищем верхние индексы и, если находим, unshiftим e^AB
	# в массив multiplicands

	foreach (@{$dpart}){
			if ($_ =~ /D(\d+)\^([A-Z])/) {
				
				$index = find_free_index (\@possible_indices_h,\@indices);
				$_ = "D$1_$index";
				unshift (@{$summands[$number]},["e^"."$2"."$index",[]])
			} elsif ($_ =~ /D(.)\^([a-z])/) {
				$index = find_free_index (\@possible_indices_l,\@indices);
				$_ = "D$1_$index";
				unshift (@{$summands[$number]},["e^"."$2"."$index",[]]);
			}
	}

}


# Функция для копирования слагаемого нашей сложной структуры
# Аргументы: (номер копируемого элемента, на какое место вставить-остальное сдвинуть вправо)

sub copy_summand{
	my ($from, $to) = @_;

	my $i;

	for ($i = @summands-1; $i >= $to; $i--) {
		$summands[$i+1] = $summands[$i];
		$coeff[$i+1] = $coeff[$i];
	}
	
	if ($from > $to) {
		$from++;
	}

	$summands[$to] = [ [ 'type' , [] ] ];

	$coeff[$to] = $coeff[$from];

	for ($i = 0; $i <= @{$summands[$from]}-1; $i++){
		$summands[$to][$i][0] = $summands[$from][$i][0];
#		print $summands[$to][$i][0];
		$summands[$to][$i][1] = [@{$summands[$from][$i][1]}];
	}

}


# Маленькая функция-помощник для derivatives_commute -- проверяет "а нужно ли?"
# аргументы - (номер слагаемого, номер сомножителя в multiplicands=номер массива factor)
# возвращает "exit", если не нужно (все D стоят слева от "D с чертой")

sub derivatives_order {
	
	my ($summand, $multiplicand) = @_; # получаем номера слагаемого и сомножителя

	my @initial_check = (); # сюда запишем маску 000111
	my @what_to_get; # идеальный случай, когда ничего делать не нужно

	foreach (@{$summands[$summand][$multiplicand][1]}) {
		if ($_ =~ /D(\d+)\_([a-z])/) { # если маленький индекс = 1 (D с чертой)
			push (@initial_check, 1);
		} else {
			push (@initial_check, 0);
		}

	}

	@what_to_get = sort @initial_check;
	if (@initial_check ~~ @what_to_get) {
		return "exit";
	} else {
		return "need_to_work";
	}


}

# Новая функция - коммутация сопряженных ковариантных производных вправо к дельта-функции,
# одновременно увеличивая количество слагаемых, вынося коэффициенты и помня, что D^n=0, n>=3
# аргументы - (номер слагаемого, номер сомножителя в multiplicands=номер массива factor)
# ПУСТЬ ОН УЖЕ ВЫРОВНЕН ПО ТЕТА-ИНДЕКСУ И ИНДЕКСЫ ОПУЩЕНЫ

sub derivatives_commute {

	my ($summand, $multiplicand) = @_; # получаем номера слагаемого и сомножителя


	# проверим, есть ли вообще производные, действующие на дельта-функцию. Если нет -- выход

	if (@{$summands[$summand][$multiplicand][1]} == 0) {
		return "nothing_to_do";
	}

	# Перебираем элементы массива dpart справа налево, ищем D со строчным индексом и,
	# если находим, антикоммутируем его. Для этого объявим дополнительные переменные:

	my $i; # счетчик
	my $prev_big_index; # запоминаем предыдущий большой индекс (от обычной D)
	my $curr_small_index; # запоминаем текущий маленький индекс (от D с чертой)

	my $lorentz_index; # лоренц-индекс, который будем приписывать импульсу и sgm_Ab^n
	my @possible_lorentz_indices = qw (a b c d e f g h i j k l m n o p q r s t u v w x y z);
	my @indices;

	my $previous = 2; # будем детектить, какой тип производной был на предыдущем шаге
			# если была D с чертой = 0, если просто D = 1  

	# вытащим для начала импульс из дельты
	my $momentum; # сюда его сохраним

	if ($summands[$summand][$multiplicand][0] =~ /:::(.+)$/) { # используем максимальность квантификатора
		$momentum = $1;
	}

	# теперь пойдем по каждому элементу массива dpart

	for ($i = @{$summands[$summand][$multiplicand][1]} - 1; $i >= 0; $i--) {

		# проверим на D^3=0 и, если находим, то удаляем это слагаемое (и его КОЭФФИЦИЕНТ!)
		if (&detect_D_cubed($summands[$summand][$multiplicand][1]) == 1){
			&del_array_element(\@summands,$summand);
			&del_array_element(\@coeff,$summand);
			last;
		} elsif (&derivatives_order($summand, $multiplicand) eq "exit") {

			# проверим, может уже все "D с чертой стоят справа"? Если так, то выход.
			# именно else для detect_D_cubed, потому-что оно ЧТО-ТО делает. А если и этого нет -- тогда можно и ничего не делать.
			return "nothing_to_do";
		}


		# распарсиваем ковариантную производную: ищем маленький (!) индекс и запоминаем его 
		# запоминаем тут же, кстати, признак предыдущего

		if ($summands[$summand][$multiplicand][1][$i] =~ /D(\d+)\_([a-z])/) {
			
			$curr_small_index = $2;
			
			if ($previous == 2 || $previous == 0){
				$previous = 0;
				next; # если первый с конца- D с чертой или предыдущий был D с чертой -- сразу дальше
			} elsif ($previous == 1) {
				
				$coeff[$summand] *= (-1); # записываем коэффициент от {,}=0
				($summands[$summand][$multiplicand][1][$i], $summands[$summand][$multiplicand][1][$i+1]) = ($summands[$summand][$multiplicand][1][$i+1], $summands[$summand][$multiplicand][1][$i]); # меняем местами две ковариантные производные в массиве dpart

	# а тут нужно бы создать новое слагаемое (элемент массива summands)
	# скопировать туда dpart, удалив эти две производные
	# также скопировать значение @coeff в новое, домножив его на (-2)
	# и еще добавить новых два сомножителя: sgm_${prev_big_index}$2^n и _n:::pprint "changed\n";

				&copy_summand($summand,$summand+1); # копируем слагаемое в соседнюю ячейку
				$coeff[$summand+1] *= 2; # добавляем коэффициент *2 (-1 уже есть) из антикоммутатора

				# у нового слагаемого удаляем в dpart пару производных
				&del_array_element($summands[$summand+1][$multiplicand][1],$i);
				&del_array_element($summands[$summand+1][$multiplicand][1],$i);
				
			# добавим еще и сигмы вместе с импульсом
			# импульс уже вытащили, он сидит в $momentum

				# сначала найдем свободный лоренцев индекс
				@indices = &lorentz_indices_used($summand+1);
				$lorentz_index = &find_free_index (\@possible_lorentz_indices,\@indices);

				unshift(@{$summands[$summand+1]}, ["_${lorentz_index}:::$momentum", [] ]);

				unshift(@{$summands[$summand+1]}, ["sgm_${prev_big_index}${curr_small_index}^$lorentz_index", [] ]);


				# а теперь включаем рекурсию - вызвываем функцию коммутации для	
				# summand+1-ого слагаемого, а в нем $multiplicand+2-ой сомножитель
				# т.к добавились sgmAb^n и _n:::p 

				&derivatives_commute($summand+1,$multiplicand+2);

				# тут подготавливаем перменные цикла для прохождения цикла снова!
				$previous = 2;
				$i = @{$summands[$summand][$multiplicand][1]};
			}

	
		} elsif ($summands[$summand][$multiplicand][1][$i] =~ /D(\d+)\_([A-Z])/) {
			$prev_big_index = $2;
			$previous = 1; # в случае обнаружения простой D (без черты) -- метка
		}
	}

	return "good";

}


# Функция - перебрасывание внешней (самой левой) производной, действующей на сомножитель, по частям
# Аргументы - (номер слагаемого, номер сомножителя)

sub byparts_ext_der {

	my ($summand, $multiplicand) = @_; # получаем номера слагаемого и сомножителя


	# проверим, есть ли вообще производные, действующие на дельта-функцию. Если нет -- выход

	if (@{$summands[$summand][$multiplicand][1]} == 0) {
		return "nothing_to_do";
	}
	
	my $derivative = $summands[$summand][$multiplicand][1][0]; # запоминаем внешнюю производную, которую собираемся перебрасывать по частям

#	print "Перебрасываем $derivative \n";
	
	&del_array_element ($summands[$summand][$multiplicand][1], 0); # удаляем ее теперь из массива dpart текущего сомножителя

	## далее будем вставлять новые слагаемые (правило Лейбница) с учетом ЗНАКА!

	my $i; # счетчик

	# найдем, с какого сомножителя заканчиваются всякие эпсилоны (коммутирующие сомножители)

	my $index_start; 

	for ($i = 0; $i <= @{$summands[$summand]}-1; $i++) {
		if ($summands[$summand][$i][0] =~ /^(?:dd)|(?:f)|(?:F)|(?:V)/){
			
			$index_start = $i;
			last;

		}
	}

	# поехали: сначала идем по сомножителям: от текущего+1 до последнего=(колич. сомножителей-1)
	# такой порядок этих двух блоков потому, что вставляется слагаемое сразу же за текущим - удобнее читать

	for ($i = $multiplicand + 1; $i <= @{$summands[$summand]}-1; $i++) {
		
		&copy_summand($summand,$summand+1); # копируем слагаемое в соседнюю ячейку
		
		# посчитаем количество производных, сквозь которые проходит оператор до $i-ого
		my $count; # счетчик
		my $total = @{$summands[$summand][$multiplicand][1]}; # количество D
		for ($count = $multiplicand + 1; $count <= $i-1; $count++) {
			$total += @{$summands[$summand][$count][1]}
		}

		$coeff[$summand+1] *= (-1)**($total+1); # добавляем коэффициент

		unshift (@{$summands[$summand+1][$i][1]}, $derivative); # вставляем новую производную в массив dpart нового слагаемого
	}

	# продолжаем:  теперь идем по сомножителям: от нулевого до текущего-1

	for ($i = $index_start; $i <= $multiplicand - 1; $i++) {
		
		&copy_summand($summand,$summand+1); # копируем слагаемое в соседнюю ячейку
		
		# посчитаем количество производных, сквозь которые проходит оператор до $i-ого
		my $count; # счетчик
		my $total = 0; # количество D
		for ($count = $multiplicand - 1; $count >= $i; $count--) {
			$total += @{$summands[$summand][$count][1]}
		}

		$coeff[$summand+1] *= (-1)**($total+1); # добавляем коэффициент

		unshift (@{$summands[$summand+1][$i][1]}, $derivative); # вставляем новую производную в массив dpart нового слагаемого

	}

	# теперь удаляем само слагаемое, из которого всё и пошло

	&del_array_element (\@summands, $summand);
	&del_array_element (\@coeff, $summand);
	
	return "good";
}


# Функция -- вычисление выражений с голой дельта-функцией и/или двумя дельта-функциями по краям
# У дельта-функций одинаковый набот тета-индексов (dd1_2 и dd2_1, например)
# в ином случае - интегрирование этой дельта-функции и замена бОльшего индекса на меньший у всех
# сомножителей этого конкретного слагаемого
# Аргумент: (номер слагаемого)
# P.S Правильно будет пускать только на "прокоммутированное на D с чертой в право" слагаемое

sub two_dd_one_naked {

	my $summand = shift; # номер слагаемого

	## Сначала отыщем голую дельта-функцию

	my ($index1, $index2) = (0, 0); # тета-индексы дельта-функции
	my $multiplicand; # номер сомножителя с голой дельта-функцией

	my $i; # счетчик

	for ($i = 0; $i <= @{$summands[$summand]}-1; $i++) {
		if ($summands[$summand][$i][0] =~ /^dd(\d+)_(\d+)\:::(.+)/) {
			if (@{$summands[$summand][$i][1]} == 0) {
				($index1, $index2) = ($1, $2);

				$multiplicand = $i;

			}
			
		}
	}

	if (! $multiplicand) { # не нашли
#		print "В этом слагаемом нет голых дельта-функций";
		return "nothing_to_do";
	}

	## Теперь ищем дельта-функцию с такими же тета-индексами (главное не наткнуться на себя же)
	# проверям с помощью regexp'ов
	

	for ($i = 0; $i <= @{$summands[$summand]}-1; $i++) {

		if ($i == $multiplicand) { # чтобы не наткнуться на ту же дельту ("голую")
			$i++;
		}

		if ($summands[$summand][$i][0] =~ /^dd[$index1$index2]\_[$index1$index2]/) {

			if (@{$summands[$summand][$i][1]} <= 3) { # то есть dd DDD dd и меньше - удалить слагаемое
				&del_array_element(\@summands,$summand);
				&del_array_element(\@coeff,$summand);
				return "good";
				
			} elsif (@{$summands[$summand][$i][1]} == 4) { # если dd DDDD dd =4e_AB e_ab dd
				# соберем все индексы у ковариантных производных

				my @temp = (); # сюда

				foreach (@{$summands[$summand][$i][1]}) {
					if (/D(\d+)\_([A-Za-z])/) {
						push (@temp, $2);
					}

				}

				# удалим лучше этот сомножитель
				&del_array_element($summands[$summand],$i);
				$coeff[$summand] *= 4;	# коэффициент умножаем на 4
				# Вставляем в начала два эпсилона
				unshift (@{$summands[$summand]}, ["e_$temp[0]$temp[1]",[]]);
				unshift (@{$summands[$summand]}, ["e_$temp[2]$temp[3]",[]]);
				return "good";
			}
			
		} # если нет таких же дельта-функций -- тогда интегрируем ее по бОльшему индексу

	}

	## в цикле будет оператор return, чтобы закончить подпрограмму
	# сюда же исполнение подпрограмме передастся только в случае отсутствия дельта-функций с 
	# такими же тета-индексами


	# $index1 должен быть в нашей подпрограмме меньше $index2, если не так - меняем местами

	if ($index2 < $index1){
		($index1, $index2)=($index2, $index1);
	}

	# будем избавляться от $index2 в D, F, f, V, dd всех сомножителей и, естественно, самой dd!

	&del_array_element($summands[$summand],$multiplicand); # сначала ее "проинтегрируем"-удалим
	
	# пойдем по сомножителям
	for ($i = 0; $i <= @{$summands[$summand]}-1; $i++) {
			#замена в секции type
		$summands[$summand][$i][0] =~ s/^dd$index2\_(\d+)/dd$index1\_$1/;
		$summands[$summand][$i][0] =~ s/^dd(\d+)\_$index2/dd$1\_$index1/;
		$summands[$summand][$i][0] =~ s/^F$index2/F$index1/;
		$summands[$summand][$i][0] =~ s/^f$index2/f$index1/;
		$summands[$summand][$i][0] =~ s/^V$index2/V$index1/;
			#замена в секции dpart
		if ($summands[$summand][$i][0] =~ /(?:^dd)|(?:^F)|(?:^f)|(?:^V)/) {
			foreach (@{$summands[$summand][$i][1]}) {
				s/$index2/$index1/;
			}
		}

	}
	return "good";
}

# Функция поиска дельта-функций в слагаемом и вывод их позиций (номера сомножителя) в виде списка
# Аргумент - (номер слагаемого)

sub find_dd {

	my $summand = shift; # считали номер слагаемого из входа
	my @found_dd; # сюда будем записывать номера сомножителей-дельт

	my $i; # счетчик

	# идем по сомножителям

	for($i = 0; $i <= @{$summands[$summand]}-1; $i++) {
		
		if ($summands[$summand][$i][0] =~ /^dd/) { # если нашли дельта-функцию сомножителем
			# если количество дельта-функций в ней меньше, чем в 0-ом элементе @found_dd
			# то помещаем ее индекс на нулевое место: т.о. $found_dd[0]-индекс сомножителя с наименьшим количеством производных
			if ($found_dd[0] && (@{$summands[$summand][$i][1]} < @{$summands[$summand][$found_dd[0]][1]})) {

				unshift (@found_dd, $i);

			} else {

				push (@found_dd, $i);

			}

		}
	
	}

	@found_dd;

}


# Функция - цикл полной отработки слагаемого (избавления от дельта-функций)
# Аргумент - (номер слагаемого)

sub workout_summand {

	my $summand = shift; # считали аргумент (номер слагаемого)
	my $dd_with_min_D; # будем хранить индекс сомножителя с минимальным числом производных

	my @temp; # временное хранилище индексов

	while (&find_dd($summand) != 0) { # пока еще есть дельта-функции в слагаемом

		@temp = &find_dd($summand);
		$dd_with_min_D = $temp[0]; # запишем индекс dd с min числом D

		# перебрасываем по частям производную с этого сомножителя на другие => появляются другие слагаемые справа (!), о них не заботимся в этой итерации цикла, они будут обработаны в следующем вызове всей нашей подпрограммы workout_summand

		if (&byparts_ext_der($summand,$dd_with_min_D) ne "nothing_to_do") {

#			print "Перебрасываем по частям производную в $summand-ом слагаемом, $dd_with_min_D-ом сомножителе: \n";
#			print &show_state();
		}

		# далее производим упрощение выражений с дельта-функцией у всего слагамого: в цикле для каждого сомножителя, на котором есть дельты
		
		foreach (@temp) {

			if (&derivatives_commute($summand,$_) ne "nothing_to_do") {
#				print "Коммутируем все производные \"D с чертой\" вправо в $summand-ом слагаемом, $_-ом сомножителе: \n";
#				print &show_state();
			}


		}

		# теперь проверяем на наличие "голой" дельта-функции, и, если найдем, интегрируем ее

		if (&two_dd_one_naked($summand) ne "nothing_to_do") {

#			print "Проверяем на наличие \"голых\" дельта-функций в $summand-ом слагаемом: \n";
#			print &show_state();
		}


	}

}

# Функция -- проверка существования "D с чертой" в dpart
# аргументы - (номер слагаемого, номер сомножителя в multiplicands=номер массива factor)
# возвращает 0, если "нет D с чертой" в dpart

sub isthere_D_bar {
	
	my ($summand, $multiplicand) = @_; # получаем номера слагаемого и сомножителя

	my $result = 0; # сюда будем прибавлять единичку, если найдем "D с чертой"

	foreach (@{$summands[$summand][$multiplicand][1]}) {
		if ($_ =~ /D(\d+)\_([a-z])/) { # если маленький индекс = 1 (D с чертой)
			$result += 1;
		}
	}

	return $result;
}


# Функция - коммутация сопряженных ковариантных производных вправо к ПОЛЮ (!) F (не сопряженному),
# одновременно увеличивая количество слагаемых, вынося коэффициенты и помня, что D^n=0, n>=3
# а также пользуясь киральностью поля: D1_a F = 0;
# аргументы - (номер слагаемого, номер сомножителя в multiplicands=номер массива factor)

sub derivatives_commute_fields {

	my ($summand, $multiplicand) = @_; # получаем номера слагаемого и сомножителя


	# проверим, есть ли вообще производные, действующие на ПОЛЕ. Если нет -- выход

	if (@{$summands[$summand][$multiplicand][1]} == 0) {

		return "nothing_to_do";
	}

	# Перебираем элементы массива dpart справа налево, ищем D со строчным индексом и,
	# если находим, антикоммутируем его. Для этого объявим дополнительные переменные:

	my $i; # счетчик
	my $prev_big_index; # запоминаем предыдущий большой индекс (от обычной D)
	my $curr_small_index; # запоминаем текущий маленький индекс (от D с чертой)

	my $lorentz_index; # лоренц-индекс, который будем приписывать импульсу и sgm_Ab^n
	my @possible_lorentz_indices = qw (a b c d e f g h i j k l m n o p q r s t u v w x y z);
	my @indices;

	# вытащим для начала импульс из ПОЛЯ
	my $momentum; # сюда его сохраним

	if ($summands[$summand][$multiplicand][0] =~ /:::(.+)$/) { # используем максимальность квантификатора
		$momentum = $1;
	}

	# теперь пойдем по каждому элементу массива dpart

	for ($i = @{$summands[$summand][$multiplicand][1]} - 1; $i >= 0; $i--) {

		# проверим на D^3=0 и, если находим, то удаляем это слагаемое (и его КОЭФФИЦИЕНТ!)
		if (&detect_D_cubed($summands[$summand][$multiplicand][1]) == 1){
			&del_array_element(\@summands,$summand);
			&del_array_element(\@coeff,$summand);
			last;
		} elsif ($summands[$summand][$multiplicand][1][-1] =~ /D(\d+)\_([a-z])/) {

		# проверим, может уже "D с чертой" стоит справа? Если так - удалить summand!

			&del_array_element(\@summands,$summand);
			&del_array_element(\@coeff,$summand);
			last;

		} elsif (! &isthere_D_bar($summand,$multiplicand)) { 
		
		# а может "D с чертой" в dpart вообще нет? Если так, то выход.
			
			return "nothing_to_do";

		}


		# распарсиваем ковариантную производную: ищем маленький (!) индекс и запоминаем его 
		# запоминаем тут же, кстати, признак предыдущего

		if ($summands[$summand][$multiplicand][1][$i] =~ /D(\d+)\_([a-z])/) {
			
			$curr_small_index = $2;
				
			$coeff[$summand] *= (-1); # записываем коэффициент от {,}=0
			($summands[$summand][$multiplicand][1][$i], $summands[$summand][$multiplicand][1][$i+1]) = ($summands[$summand][$multiplicand][1][$i+1], $summands[$summand][$multiplicand][1][$i]); # меняем местами две ковариантные производные в массиве dpart

	# а тут нужно бы создать новое слагаемое (элемент массива summands)
	# скопировать туда dpart, удалив эти две производные
	# также скопировать значение @coeff в новое, домножив его на (-2)
	# и еще добавить новых два сомножителя: sgm_${prev_big_index}$2^n и _n:::pprint "changed\n";

			&copy_summand($summand,$summand+1); # копируем слагаемое в соседнюю ячейку
			$coeff[$summand+1] *= 2; # добавляем коэффициент *2 (-1 уже есть) из антикоммутатора

			# у нового слагаемого удаляем в dpart пару производных
			&del_array_element($summands[$summand+1][$multiplicand][1],$i);
			&del_array_element($summands[$summand+1][$multiplicand][1],$i);
				
			# добавим еще и сигмы вместе с импульсом
			# импульс уже вытащили, он сидит в $momentum

			# сначала найдем свободный лоренцев индекс
			@indices = &lorentz_indices_used($summand+1);
			$lorentz_index = &find_free_index (\@possible_lorentz_indices,\@indices);

			unshift(@{$summands[$summand+1]}, ["_${lorentz_index}:::$momentum", [] ]);

			unshift(@{$summands[$summand+1]}, ["sgm_${prev_big_index}${curr_small_index}^$lorentz_index", [] ]);


			# а теперь включаем рекурсию - вызвываем функцию коммутации для	
			# summand+1-ого слагаемого, а в нем $multiplicand+2-ой сомножитель
			# т.к добавились sgmAb^n и _n:::p 

			&derivatives_commute_fields($summand+1,$multiplicand+2);

			# тут подготавливаем перменные цикла для прохождения цикла снова!
			$i = @{$summands[$summand][$multiplicand][1]};

	
		} elsif ($summands[$summand][$multiplicand][1][$i] =~ /D(\d+)\_([A-Z])/) {
			$prev_big_index = $2;
		}
	}

	return "good";

}

# Функция поиска поля f/F в слагаемом и вывод его позиций (номера сомножителя)
# Аргумент - (номер слагаемого, тип поля [F или f])

sub find_f {

	my $summand = shift; # считали номер слагаемого из входа
	my $field_type = shift; # считали тип поля

	my $i; # счетчик

	# идем по сомножителям

	for($i = 0; $i <= @{$summands[$summand]}-1; $i++) {
		
		if ($summands[$summand][$i][0] =~ /^$field_type/) { # если нашли поле сомножителем
			return $i;
		}
	}

	return -1; # в случае, если не нашли
}


# Функция полной отработки слагаемого: убрать производные на полях
# сначала по частям перебрасываем ВСЕ их с f на F, затем derivatives_commute_fields -- остаток=0, то есть если остались на F еще производные (только D без черты могут) -- тут просто проверить объем dpart
# аргумент = (номер слагаемого)

sub workout_summand_fields {

	my $summand = shift; # считали аргумент (номер слагаемого)

	my $index_f = &find_f($summand,"f"); # индекс поля f
	my $index_F = &find_f($summand,"F"); # индекс поля F

	# перебрасываем ВСЕ производные с поля f на поле F

	while (@{$summands[$summand][$index_f][1]} != 0) {
	
		&byparts_ext_der($summand, $index_f);
		&derivatives_commute_fields($summand,$index_F);
		$index_f = &find_f($summand,"f");
		$index_F = &find_f($summand,"F");
	}

	#теперь коммутируем производные в сомножителе DD DD F

	$index_F = &find_f($summand,"F"); # снова ищем -- повылазили эпсилоны, могло все поменяться
	
	if (@{$summands[$summand][$index_F][1]} != 0) { # если остались производные - удалить слагаемое
		&del_array_element(\@summands,$summand);
		&del_array_element(\@coeff,$summand);
		return "deleted_summand";

	}

	return "good";
}

############### Набор подпрограмм для свертки индексов

# Функция поиска эпсилон-символов с нижними (low) и верхними (top) индексами и выдачи их индексов
# Аргументы = (номер слагаемого, "low"/"top","certain"/"any", индекс1, индекс2 (не важен порядок)) 
# возвращает список индексов в массиве (при "any") или сам индекс, если "certain" (-1, если не нашел)
# то есть номеров сомножителей

sub find_e {

	my $summand = shift; # считали аргумент (номер слагаемого)
	my $e_type = shift; # считали строку-тип индекса

	my $type_of_search = shift;

	my $index1 = shift; # переданные индексы
	my $index2 = shift;

	my @output; # список индексов

	my $i; # счетчик
	my $symbol_height; #высота индекса

	# назначим, верхний или нижний индекс нам нужно искать:
	
	if ($e_type eq "low") {
		$symbol_height = '_';

	} elsif ($e_type eq "top") {
		$symbol_height = '\^';

	}

	# теперь поиск:

	if ($type_of_search eq "any") {

		for ($i = 0; $i <= @{$summands[$summand]}-1; $i++) {
			if ($summands[$summand][$i][0] =~ /^e$symbol_height(.)(.)/) {
				push (@output, $i);
			}
		}

		return @output;

	} elsif ($type_of_search eq "certain") {

		for ($i = 0; $i <= @{$summands[$summand]}-1; $i++) {
			if ($summands[$summand][$i][0] =~ /e$symbol_height$index1$index2|e$symbol_height$index2$index1/) {
				return $i;
			}
		}

		return -1;

	}

}

# Функция поиска пары сигма-матриц по данным индексами и возврата их индекса в массиве сомножителей
# Аргументы = (номер слагаемого, первый индекс, второй индекс)
# возвращает еще и признак "A" или "a" -- верхний или нижний (1ый или 2ой) был подан индекс

sub find_certain_sigma {

	my $summand = shift; # считали номер слагаемого

	my ($sgm1, $sgm2) = @_; # считали индексы, какие были у эпсилона-top, нужно найти sgm с ними

	my $i; # счетчик

	my @sigmas; # сюда запишем номера сомножителей с сигмами

	# пойдем по сомножителям

	for ($i = 0; $i <= @{$summands[$summand]}-1; $i++) {

		if ($summands[$summand][$i][0] =~ /sgm_$sgm1(.)\^(.)/) {

			unshift (@sigmas, $i);

		}

		if ($summands[$summand][$i][0] =~ /sgm_$sgm2(.)\^(.)/) {

			push (@sigmas, $i);

		}


	}

	return @sigmas; # [0] - соответствует index1; [1] -соответствует index2
}


# Функция свертки эпсилон-символов
# Аргумент = (номер слагаемого)

sub epsilon_convolution {

	my $summand = shift; # считали аргумент (номер слагаемого)
	my @list_of_e_low; # список индексов e_;

	my @list_of_sgm; # список индексов sgm

	my $index; #temp'овая переменная - номер сомножителя
	my ($index1, $index2);
	my ($second_index1, $second_index2, $lorentz1, $lorentz2);
	my $second_e;

	# цикл для избавления от эпсилонов с нижними индексами (и с верхними ТАКИМИ ЖЕ!)

	while (&find_e($summand, "low", "any", "a", "a") != 0) {

		@list_of_e_low = &find_e($summand, "low", "any", "a", "a");
 	
		if ($summands[$summand][$list_of_e_low[0]][0] =~ /e_(.)(.)/) {
	
			$index = &find_e($summand, "top", "certain", $1, $2);
			($index1, $index2) = ($1, $2);
		}

		if ($index == -1) {
			next;
		}

		if ($summands[$summand][$index][0] =~ /e\^$index1$index2/) {
	
			# удалим эти сомножители

			if ($list_of_e_low[0] > $index) {
				($list_of_e_low[0], $index) = ($index, $list_of_e_low[0]);
			}
			&del_array_element($summands[$summand],$list_of_e_low[0]);
			&del_array_element($summands[$summand],$index-1); #после первой все сдвинулось
			$coeff[$summand] *= -2;	# коэффициент умножаем на 2
			
		} elsif ($summands[$summand][$index][0] =~ /e\^$index2$index1/) {

			# удалим эти сомножители

			if ($list_of_e_low[0] > $index) {
				($list_of_e_low[0], $index) = ($index, $list_of_e_low[0]);
			}	
			&del_array_element($summands[$summand],$list_of_e_low[0]);
			&del_array_element($summands[$summand],$index-1);
			$coeff[$summand] *= 2;	# коэффициент умножаем на 2

		}

	}


	# теперь сворачиваем epsilon x epsion x sigma x sigma

	# цикл для избавления от эпсилонов с нижними индексами (и с верхними ТАКИМИ ЖЕ!)

	while (&find_e($summand, "top", "any", "a", "a") != 0) {

		@list_of_e_low = &find_e($summand, "top", "any", "a", "a"); #ищем эпсилоны с верхними инд.

		#распарсили найденный эпсилон на индексы (сначала верхние)
		my $s; # пока костЫль	
		for ($s =0 ; $s <= @list_of_e_low-1; $s++) {
			if ($summands[$summand][$list_of_e_low[$s]][0] =~ /e\^([A-Z])([A-Z])/) {
	
				($index1, $index2) = ($1, $2);
				last;

			}
		}

		# тут номера сомножителей-сигм с нужными первыми индексами - берем вторые индексы, 
		# ищем такую e^ и ... execute
		@list_of_sgm = &find_certain_sigma ($summand, $index1, $index2); 

		# узнаем вторые индексы у сигм, чтобы с такими же найти эпсилон

		if ($summands[$summand][$list_of_sgm[0]][0] =~ /sgm_.(.)\^(.)/) {
	
			($second_index1, $lorentz1) = ($1, $2);
		}

		if ($summands[$summand][$list_of_sgm[1]][0] =~ /sgm_.(.)\^(.)/) {
	
			($second_index2, $lorentz2) = ($1, $2);
		}

		# вот и номер сомножителя e^ со вторыми индексами
		
		$second_e = &find_e($summand, "top","certain", $second_index1, $second_index2);

		#узнаем порядок индексов у второго эпсилона
		my $order = 0;

		if ($summands[$summand][$second_e][0] =~ /e\^$second_index1/) {
	
			$order = 1;
		} elsif ($summands[$summand][$second_e][0] =~ /e\^$second_index2/) {
			$order = -1;
		}
 

		# наконец сворачиваем: 

		my @ordered_seq = ($list_of_e_low[$s], $list_of_sgm[0], $list_of_sgm[1], $second_e);

		@ordered_seq = sort {$b <=> $a} @ordered_seq; # для правильного последовательного удаления

		# коэффициент

		$coeff[$summand] *= $order*2;

		# удяляем элементы (обратно отсортированный массив индексов, чтобы после каждого удаления ничего не сбивалось! о как!)
		foreach (@ordered_seq) {
			&del_array_element($summands[$summand],$_);
		}

		# и наконец вставляем метрический тензор!

		unshift (@{$summands[$summand]}, ["eta\^$lorentz1$lorentz2",[]])

	}

}



			#################################
			#	   Секция кода		#
			#################################

print "Важно напомнить, что счет слагаемых или сомножителей начинается с нуля! \n \\\\";

print "Что было изначально:\n";
print &show_state();

print "Выравниваем тета-индекс у нулевого слагаемого (1 и 2 сомножитель):\n";
&index_align($summands[0][1], \@coeff, 0);
&index_align($summands[0][2], \@coeff, 0);

print &show_state();


print "Опускаем индексы у нулевого слагаемого (1 и 2 сомножитель):\n";
# меняется после первого опускания!!!
&lower_index($summands[0][1],0);
&lower_index($summands[0][4],0); # тут уже 4-ый
print &show_state();


print "Коммутируем производные с чертой вправо у нулевого слагаемого (6-ой сомножитель):\n";

&derivatives_commute(0,6);
print &show_state();

print "Запускаем ЦИКЛ!:\n";

my $counter = 0;
for ($counter = 0; $counter <= $#summands; $counter++){
	&workout_summand($counter);
}
print &show_state();

#print "К нулевому слагаемому применяем derivatives\\_commute\\_fields:\n";
#&derivatives_commute_fields(0,6);
#print &show_state();

print "Запускаем ЦИКЛ WORKOUT-ов полей:\n";
my $counter1 = 0;
for ($counter1 = 0; $counter1 <= $#summands; $counter1++){

	# Если удалили слагаемое, на его место встало следующее -- его нужно не пропустить!
	if (&workout_summand_fields($counter1) eq "deleted_summand") {
		redo;
	}

}
&workout_summand_fields(8);
print &show_state();

print "Попробуем свернуть нижние индексы у эпсилонов (ЦИКЛОМ!): \n";
#my $counter2 = 0;
#for ($counter2 = 0; $counter2 <= 22; $counter2++){
#	&epsilon_convolution($counter2);
#}

&epsilon_convolution(21);
print &show_state();


#print "Здесь пользуемся правилами преобразования выражений с \"голой\" дельта-функцией у 6-ого слагаемого:\n";

#&two_dd_one_naked(6);
#print &show_state();


#print "Еще раз пользуемся правилами преобразования выражений с \"голой\" дельта-функцией у 6-ого слагаемого:\n";

#&two_dd_one_naked(6);
#print &show_state();

#print "Интегрируем по частям крайнюю левую производную у 0-ого слагаемого, 6-ого сомножителя:\n";

#&byparts_ext_der(0,6);
#print &show_state();

#print "Еще раз интегрируем по частям крайнюю левую производную у 0-ого слагаемого, 6-ого сомножителя:\n";

#&byparts_ext_der(0,6);
#print &show_state();
