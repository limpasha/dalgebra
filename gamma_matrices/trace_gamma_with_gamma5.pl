#!/usr/bin/perl
use warnings;
use strict;

# структура: массив @matrices представляет собой массив ссылок на массивы с гамма-матрицами

my @thesum = ([qw /gamma^a gamma^b gamma^c gamma^d/], [qw /gamma^a gamma^b gamma^c gamma^d gamma5/]);
my @coef = (1/2, 1/2,);

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

# Функция для копирования элемента из массива и сдвига всех его элементов вправо, тем самым длина
# массива увеличивается на один элемент
# аргументы -- (ссылка на массив, индекс элемента для копирования, индекс - куда копировать)
# пример вызова &del_array_element (\@array, 3, 5)

sub copy_array_element {

	my $array_ref = shift;
	my ($one, $two) = @_;

	if ($one > $two) { # если номер ячейки, откуда нужно скопировать, больше номера ячейки, КУДА нужно скопировать

		$one++;

	}

	my $i; # счетчик

	# начинаем с конца -- создадим новый элемент в конце, копируем элементы по очереди с i в i+1-ый (обычный порядок), и так дойдем до $_[2] ого

	for ($i = @{$array_ref}-1; $i>= $two; $i--) {
		${$array_ref}[$i+1] = ${$array_ref}[$i]; 
	}	

	${$array_ref}[$two] = ${$array_ref}[$one]; # наконец, копируем нужное слагаемое на нужное место
	
}


# Функция копирования слагаемого нашей структуры (ибо она сплошь из ссылок состоит!!!)
# Так вот она нужно, чтобы не тупо копировать ссылки с помощью copy_array_element, а значения!
# Аргументы: (номер слагаемого, которое нужно скопировать, И куда)

sub copy_summand {

	my ($from, $to) = @_;
	my @array;

	&copy_array_element(\@thesum, $from, $to); # сначала просто скопируем (ссылки)
	&copy_array_element(\@coef, $from, $to);
	
	@array = @{$thesum[$from]}; # затем вытащим реальный массив gpart
	$thesum[$to] = [@array];
	

}

# Функция -- возвращает список индексов гамма-матриц (тем самым видно и количество гамма-матриц)
# аргумент -- ссылка на массив с гамма-матрицами

sub gammas_indices {

	my $gpart = shift;
	my @output; # ответ
	
	foreach (@{$gpart}) {

		if (/^gamma\^(.)/) {
			push (@output, $1);
		}

	}
	
	return @output;

}

# Функция -- находит gamma5 и переносит все их вправо и, записывая коэффициент (-1) соответствующий в @coef. Если их было нечетное количество - возвращает 1, оставляя gamma5 в конце. 
# аргумент -- номер слагаемого

sub gamma5_to_right {

	my $summand = shift;
	my @mask;
	my $i; # счетчик
	my $iff;

	foreach (@{$thesum[$summand]}) {

		if (/^gamma5/) {
			push (@mask, 1);
		} else {
			push (@mask, 0);
		}

	}
	
	foreach (@mask) { # вычислим признак
		$iff += $_;
	}

	my $ones = 0; # сколько уже единичек встретилось - с ними при переносе gamma5 коммутирует
 	for($i = @mask - 1; $i >= 0; $i--) { # отработаем коэффициент при коммутациях gamma5
	
		if ($mask[$i] == 1) {

			$coef[$summand] *= (-1)**(@mask-1-$i - $ones);
			$ones += 1;

		}		

	}


	# если гамма5 было четное количество -- удалим их из gpart. Тут поступим так- удалим в любом случае. Если из было нечетное - ставим снова одну штуку в конец gpart
	
	for ($i = 0; $i<=@{$thesum[$summand]} -1; $i++) {

		if ($thesum[$summand][$i] =~ /gamma5/) {
		
			&del_array_element ($thesum[$summand], $i);
			$i--;

		}

	}



	if ($iff % 2 != 0) {  # если гамма5 было нечетное количество --  вставим в конце одну

		push (@{$thesum[$summand]}, "gamma5");

		return 1; # осталась одна гамма5

	}

	return 0; # не осталось ни одной гамма5

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

# Поехали!

my ($i, $j, $k);
my $ifgamma5 = 0; # есть ли в слагаемом gamma5
my @indices;
my @possible_indices_l = qw (a b c d e f g h i j k l m n o p q r s t u v w x y z);
my $index; # сюда будем помещать найденный свободный индекс


# Выводим на экран содержание нашей структуры
print "Было: \n";
print "\n ********** OUTPUT ********* \n";

for ($i = 0; $i <= @thesum-1; $i++){
	if ($i == 0) {

		print "tr(";
	}

	print "\($coef[$i]\) x @{$thesum[$i]}";
	if ($i !=@thesum-1) {
		print " + ";
	} else {

		print ")";
	}
}
print "=";

print "\n ************ END ********* \n";




for ($i = 0; $i <= @thesum -1; $i++) { # идем по слагаемым

	$ifgamma5 = &gamma5_to_right ($i); # выровняем все гамма5 вправо, вычислим коэф. и вернем признак

	@indices = &gammas_indices($thesum[$i]); # сюда поместим все индексы гамма-матриц слагаемого

	if (@indices % 2 != 0) { # если количество гамма-матриц нечетное - удаляем

		&del_array_element (\@thesum, $i);
		&del_array_element (\@coef, $i);

		$i--;

	} 

	if (@indices == 2 && $ifgamma5 == 0) { # если осталось только 2 матрицы

		for ($j = 0; $j <= @{$thesum[$i]} - 1; $j++) { # идем по сомножителям в gpart

		
			if ($thesum[$i][$j] =~ /^gamma\^/) { # если находим гамму - удаляем ее

				&del_array_element ($thesum[$i], $j);
				$j--; # из-за смещения массива после удаления элемента

			}

		}

		unshift (@{$thesum[$i]}, "eta\^$indices[0]$indices[1]");
		$coef[$i] *= 4;

		next;

	} elsif (@indices > 2 && @indices % 2 == 0 && $ifgamma5 == 0) { # когда четное количество

		for ($j = 1; $j <= @indices - 1; $j++) { # тут будем генерить новые слагаемые

			&copy_summand($i, $i+1);

			$coef[$i+1] *= (-1)**($j+1);

			# из нового слагаемого удалим первую гамма-матрицу и еще одну j-ую

			for ($k = 0; $k <= @{$thesum[$i+1]}-1; $k++) {

				if ($thesum[$i+1][$k] =~ /gamma\^($indices[0]|$indices[$j])/) {

					&del_array_element ($thesum[$i+1], $k);
					$k--; # из-за смещения массива после удаления элемента

				}

			}


			# теперь вставим eta^$indices[0]$indices[$j]


			unshift (@{$thesum[$i+1]}, "eta^$indices[0]$indices[$j]");

		}

		# теперь удалим это слагаемое

		&del_array_element (\@thesum, $i);
		&del_array_element (\@coef, $i);

		$i--;

	}

	if (@indices == 2 && $ifgamma5 == 1) { # если осталось только 2 матрицы и гамма5

		&del_array_element (\@thesum, $i);
		&del_array_element (\@coef, $i);

		$i--;


	} elsif (@indices == 4 && $ifgamma5 == 1) { # если осталось только 4 матрицы и гамма5

		for ($j = 0; $j <= @{$thesum[$i]} - 1; $j++) { # идем по сомножителям в gpart

		
			if ($thesum[$i][$j] =~ /^gamma/) { # если находим гамму - удаляем ее

				&del_array_element ($thesum[$i], $j);
				$j--; # из-за смещения массива после удаления элемента

			}

		}

		unshift (@{$thesum[$i]}, "e\^$indices[0]$indices[1]$indices[2]$indices[3]");
		unshift (@{$thesum[$i]}, "i"); # пока так обозначим комплексную единицу!
		$coef[$i] *= -4;

		next;		

	} elsif (@indices > 4 && @indices % 2 == 0 && $ifgamma5 == 1) { # когда четное количество гамма-матриц, большее 4 и еще есть gamma5
		# здесь используем формулу для 3-х гамма матриц!
		my $count = 0;
		for ($j = 0; $j <= @indices - 1; $j++) { # идем по сомножителям в gpart - удалим первые 3 шт.
			if ($count == 3) { last };		

			if ($thesum[$i][$j] =~ /^gamma\^/) { # если находим гамму - удаляем ее

				&del_array_element ($thesum[$i], $j);
				$j--; # из-за смещения массива после удаления элемента
				$count++;

			}

		}
		

		&copy_summand($i, $i+1);
		unshift (@{$thesum[$i+1]}, "eta\^$indices[0]$indices[1]");
		unshift (@{$thesum[$i+1]}, "gamma\^$indices[2]");

		&copy_summand($i, $i+1);
		unshift (@{$thesum[$i+1]}, "eta\^$indices[1]$indices[2]");
		unshift (@{$thesum[$i+1]}, "gamma\^$indices[0]");

		&copy_summand($i, $i+1);
		unshift (@{$thesum[$i+1]}, "eta\^$indices[0]$indices[2]");
		unshift (@{$thesum[$i+1]}, "gamma\^$indices[1]");
		$coef[$i+1] *= -1;

		&copy_summand($i, $i+1);
		unshift (@{$thesum[$i+1]}, "gamma5");
		$index = find_free_index (\@possible_indices_l,\@indices);
		unshift (@{$thesum[$i+1]}, "gamma\^$index");
		unshift (@{$thesum[$i+1]}, "e_$index\^$indices[0]$indices[1]$indices[2]");
		unshift (@{$thesum[$i+1]}, "i");
		$coef[$i+1] *= -1;

		# теперь удалим это слагаемое

		&del_array_element (\@thesum, $i);
		&del_array_element (\@coef, $i);
	
		$i--;
	}

}	

# Выводим на экран содержание нашей структуры
print "\n ********** OUTPUT ********* \n";

for ($i = 0; $i <= @thesum-1; $i++){
	print "\($coef[$i]\) x @{$thesum[$i]}";
	if ($i !=@thesum-1) {
		print " + ";
	}
}
print "\n";

print "\n ************ END ********* \n";
