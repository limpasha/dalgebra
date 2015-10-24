#!/usr/bin/perl
use warnings;
use strict;
use DDP;
use feature qw (say);

			###################################
			#     Секция описания классов 	  #
			###################################


{	## Класс сомножителей (даже для ковариантной производной, хоть она и не является сомножителем в нашем понимании)
	package Multiplicand;


	# Общий для всех метод, наследуется

	sub clone {
		my ($self) = @_;
		my $class = ref $self;

		my %to_return;
		foreach my $key (keys %{ $self }) {
			if (ref $self->$key) { # в основном для dpart
				$to_return{$key} = $self->$key->clone;
			} else {
				$to_return{$key} = $self->$key;
			}
		}

		return bless \%to_return, $class;

	}


	# Аксессор (универсальный для всех экземпляров классов-наследников класса Multiplicand)
	# Разумеется, что далее будет иногда перекрываться в классах-наследниках

	our $AUTOLOAD;

	sub AUTOLOAD {
		my ($self, $arg) = @_;

		# Вытаскиваем из AUTOLOAD имя вызванного метода
		my $method_name;
		if ($AUTOLOAD =~ /::(.+?)$/) {
			$method_name = $1;
		} else {
			die "Wrong method name. May be you've mistaken? Error in AUTOLOAD";
		}

		# Если присутствовал аргумент при вызова -- значит сеттер
		if ($arg) { 
			$self->{$method_name} = $arg;
		} 

		return $self->{$method_name};
	}

	# Getter/Setter D-части каждого сомножителя
	sub dpart {
		my ($self, $arg) = @_;

		if ($arg) { 
			$self->{dpart} = DPart->new ($arg);
		} 

		return $self->{dpart};
	}

}

{	## Дельта-функция Дирака

	package DiracDelta;
	use base qw (Multiplicand); # наследуется от класса сомножителей

	# Конструктор
	sub new {
		my ($class, $data, $if_dpart, $dpart) = @_;

		# Как бы десериализация из текстового вида
		my ($point1, $point2, $momentum);
		if ($data =~ /^dd(.+?)_(.+?):::(.+)/) {
			($point1, $point2, $momentum) = ($1, $2, $3);
		} else {
			die "Can't deserialize data in $class constructor";
		}

		# Если есть в аргументах вызова конструктора строка dpart => "D1_A ..."
		if (defined ($if_dpart) and ($if_dpart eq 'dpart')) {
			$dpart = DPart->new ($dpart);
		} else {
			$dpart = DPart->new ("");
		}

		return bless {
					
						dpart => $dpart,
						point1 => $point1,
						point2 => $point2,
						momentum => $momentum,
					
					}, $class;
	}


	# Для вывода -- сериализация (так же является обработчиком перегруженного оператора преобразования в строку)
	sub print {
		my ($self) = @_;

		return $self->dpart->print.'dd'.$self->point1.'_'.$self->point2.':::'.$self->momentum;
	}


	# Для вырвнивания индекса у ковариантных производных, действующих на эту Дельта-функцию
	sub index_align {
		my ($self) = @_;

		my $coef = 1; # сюда будем писать новый коэффициент, который метод будет возвращать
		my $dpart = DPart->new(""); # формируем по дороге новую dpart, которой далее заменим старую
		my ($j, $k) = ($self->point1, $self->point2); # считаем значение индексов (координат) у Дельта-функции

		# j должна быть в нашей подпрограмме меньше k, если не так - меняем местами
		if ($j > $k){
			($j, $k)=($k, $j);
		}

		# Теперь идем от конца массива dpart справа налево
		for (my $i = $self->dpart->size-1; $i >= 0; $i--) {
			if ($self->dpart->element($i)->point eq $k) { # проверяем у производной наличие индекса $k, большего $j
				$self->dpart->element($i)->point($j); # заменяем на $j в случае совпадения
				$dpart->push_der(object => $self->dpart->element($i)); # добавляем в конец нового массива
				$coef *= (-1)**($self->dpart->size - $i); # степень (-1) считаем и пишем коэф.

			} else {
				$dpart->unshift_der(object => $self->dpart->element($i)); # добавляем в начало нового массива
			}
		}

		# заменяем старый DPart новым, выровненным по индексу координат
		$self->{dpart} = $dpart; # тут придется вмешаться в структуру и заменить именно элемент хеша

		return $coef; # возвращаем коэффициент

	}


}


{	## Киральное суперполе

	package ChiralSfield;
	use base qw (Multiplicand); # наследуется от класса сомножителей

	# Конструктор
	sub new {
		my ($class, $data, $if_dpart, $dpart) = @_;

		# Как бы десериализация из текстового вида
		my ($kind, $point, $momentum);
		if ($data =~ /^(.)(.+?):::(.+)/) {
			($kind, $point, $momentum) = ($1, $2, $3);
		} else {
			die "Can't deserialize data in $class constructor";
		}

		if ($kind eq 'F') {
			$kind = 'Chiral';
		} elsif ($kind eq 'f') {
			$kind = 'AntiChiral';
		} else {
			die "Bad ChiralSfield first letter. Error in constructor";
		}

		# Если есть в аргументах вызова конструктора строка dpart => "D1_A ..."
		if (defined ($if_dpart) and ($if_dpart eq 'dpart')) {
			$dpart = DPart->new ($dpart);
		} else {
			$dpart = DPart->new ("");
		}

		return bless {
					
						dpart => $dpart,
						kind => $kind,
						point => $point,
						momentum => $momentum,
					
					}, $class;
	}


	# Для вывода -- сериализация (так же является обработчиком перегруженного оператора преобразования в строку)
	sub print {
		my ($self) = @_;

		# Вычисляем первую букву для десериализации
		my $kind_letter;
		if ($self->kind eq 'Chiral') {
			$kind_letter = 'F';
		} elsif ($self->kind eq 'AntiChiral') {
			$kind_letter = 'f';
		} else {
			die "ChiralSfield has bad kind_letter [F/f]";
		}

		return $self->dpart->print.$kind_letter.$self->point.':::'.$self->momentum;
	}


}


{	# Массив ковариантных производных, действующих на сомножитель

	package DPart; 

	# Конструктор
	sub new {
		my ($class, $rawdata) = @_;

		my @array_text = split / /, $rawdata; # делим помноженные друг на друга ковариантные производные
		# Как бы десериализация из текстового вида
		my @array_obj;
		foreach my $derivative_text (@array_text) {

			push @array_obj, Derivative->new($derivative_text);
		}

		return bless \@array_obj, $class;
	}

	sub clone {
		my ($self) = @_;
		my $class = ref $self;

		my @to_return;
		for (my $i = 0; $i < $self->size; $i++) {
			push @to_return, $self->element($i)->clone;
		}
		return bless \@to_return, $class;
	}

	# Аксессор к элементам получившегося объекта (по сути массива)
	sub element {
		my ($self, $element, $if_set, $value_to_set) = @_;

		# Если есть в аргументах вызова конструктора строка set => Derivative->new ("..."), то есть сеттер
		if (defined ($if_set) and ($if_set eq 'set')) {
			$self->[$element] = Derivative->new($value_to_set);
		}

		# Если есть в аргументах вызова конструктора строка delete => 4 -- удалим ее и вернем уже новый 4-ый (бывший 5-ый) (все остальыне элементы сдвинутся влево)
		if (defined ($if_set) and ($if_set eq 'delete')) {

			for (my $i = $element; $i<= @{$self} - 1; $i++) {
				$self->[$i] = $self->[$i+1];
			}
			pop @{$self};
		}

		return $self->[$element];
	}

	sub unshift_der {
		my ($self, $if_set, $value_to_set) = @_;

		# Если есть в аргументах вызова конструктора строка derivative => "...", то есть сеттер, который нужно десериализовать
		if (defined ($if_set) and ($if_set eq 'derivative')) {
			unshift @{$self}, Derivative->new($value_to_set);
		}

		# Если есть в аргументах вызова конструктора строка derivative => Derivative->new ("..."), который подает только объект
		if (defined ($if_set) and ($if_set eq 'object')) {
			unshift @{$self}, $value_to_set;
		}

		return $self->[0]; # возвращает этот новый объект
	}

	sub push_der {
		my ($self, $if_set, $value_to_set) = @_;

		# Если есть в аргументах вызова конструктора строка derivative => "...", то есть сеттер, который нужно десериализовать
		if (defined ($if_set) and ($if_set eq 'derivative')) {
			push @{$self}, Derivative->new($value_to_set);
		}

		# Если есть в аргументах вызова конструктора строка derivative => Derivative->new ("..."), который подает только объект
		if (defined ($if_set) and ($if_set eq 'object')) {
			push @{$self}, $value_to_set;
		}

		return $self->[-1]; # возвращает этот новый объект
	}

	# Функция, отслеживающая наличие произведения трех ковариантных производных (с чертой или без)
	# и при нахождении -- сообщающая об этом

	sub detect_D_cubed {
		my ($self) = @_;

		my @detect = (); # будем записывать сюда признак ковариантной производной: с чертой/без

		# обращаем массив DPart и таким образом идем от конца dpart-массива к началу

		for(my $i = $self->size-1; $i >= 0; $i--) {
			if ($self->element($i)->kind eq 'Chiral') {	# если простая ковариантная производная: добавляем в начало массива 0
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

	# Запрос на количество элементов в DPart
	sub size {
		my ($self) = @_;
		return $#{$self}+1;
	}

	sub print {
		my ($self) = @_;
		my $to_print='';

		for (my $i = 0; $i < $self->size; $i++) {
			$to_print = $to_print.$self->element($i)->print.' '; 
		}

		return $to_print;

	}

}

{	# Ковариантная производная

	package Derivative; 
	use base qw (Multiplicand);

	# Конструктор
	sub new {
		my ($class, $data) = @_;

		# Как бы десериализация из текстового вида
		my ($point, $height, $spinor_index);

		if ($data =~ /^D(.+?)([\_\^])(.+)/) {
			($point, $height, $spinor_index) = ($1, $2, $3);
		} else {
			die "Detected a try to create an object of $class class with empty argument in constructor";
		}

		# тип индекса (верхний или нижний)
		if ($height eq '_') {
			$height = 'Lower';
		} elsif ($height eq '^') {
			$height = 'Upper';
		} else {
			die "Can't resolve the height of spinor_index in $class constructor";
		}

		my $kind; # тип производной (киральная или антикиральная)
		if ($spinor_index =~ /[A-Z]+/) {
			$kind = 'Chiral';
		} elsif ($spinor_index =~ /[a-z]+/) {
			$kind = 'AntiChiral';
		} else {
			die "Can't resolve kind of index in $class constructor";
		}
		
		return bless {

						kind => $kind,
						height => $height,			
						point => $point,
						index => $spinor_index,
					
					}, $class;
	}

	sub print {
		my ($self) = @_;

		my $height_symbol;
		if ($self->height eq 'Upper') {
			$height_symbol = '^';
		} elsif ($self->height eq 'Lower'){
			$height_symbol = '_';
		} else {
			die "Can't resolve height_symbol of Derivative in printing hook";
		}


		return "D".$self->point.$height_symbol.$self->index;
	}


}


{
	# Вещественное скалярное суперполе

	package RealSfield;
	use base qw (Multiplicand); # наследуется от класса сомножителей

	# Конструктор
	sub new {
		my ($class, $data, $if_dpart, $dpart) = @_;

		# Как бы десериализация из текстового вида
		my ($point, $momentum);
		if ($data =~ /^V(.+?):::(.+)/) {
			($point, $momentum) = ($1, $2);
		} else {
			die "Can't deserialize data in $class constructor";
		}

		# Если есть в аргументах вызова конструктора строка dpart => "D1_A ..."
		if (defined ($if_dpart) and ($if_dpart eq 'dpart')) {
			$dpart = DPart->new ($dpart);
		} else {
			$dpart = DPart->new ("");
		}

		return bless {
					
						dpart => $dpart,
						point => $point,
						momentum => $momentum,
					
					}, $class;
		}

	# Для вывода -- сериализация (так же является обработчиком перегруженного оператора преобразования в строку)
	sub print {
		my ($self) = @_;

		return $self->dpart->print.'V'.$self->point.':::'.$self->momentum;
	}


}

### --------------------------------------------------------------------------
### Не дифференцируемые сомножители (не зависящие от координат) и к тому же коммутирующие (грассманово четные)


{
	# Сигма-матрица
	package SigmaMatrix;
	use base qw (Multiplicand);


	sub new {
		my ($class, $data) = @_;

		my ($index1, $index2, $lorentz_index);
		if ($data =~ /^sgm_([A-Z]+?)([a-z]+?)\^(.+)/) {
			($index1, $index2, $lorentz_index) = ($1, $2, $3);
		}

		return bless {
					
						index1 => $index1,
						index2 => $index2,
						lorentz_index => $lorentz_index,
					
					}, $class;
		}

	sub print {
		my ($self) = @_;

		return 'sgm_'.$self->index1.$self->index2.'^'.$self->lorentz_index;
	}
}

{
	# Эпсилон-символ
	package EpsilonSymbol;
	use base qw (Multiplicand);
	

	sub new {
		my ($class, $data) = @_;

		my ($height_symbol, $index1, $index2);
		
		if ($data =~ /^e([_\^])([A-Z]+),([A-Z]+)$/) {
			($height_symbol, $index1, $index2) = ($1, $2, $3);
		} elsif ($data =~ /^e([_\^])([a-z]+),([a-z]+)$/) {
			($height_symbol, $index1, $index2) = ($1, $2, $3);
		} else {
			die "Can't deserialize data in $class";
		}

		# Узнаем высоту индексов
		my $height;
		if ($height_symbol eq '_') {
			$height = 'Lower';
		} elsif ($height_symbol eq '^') {
			$height = 'Upper';
		} else {
			die "Can't deserialize height in $class";
		}

		# Узнаем тип индексов (большие или маленькие) на основе первого
		my $kind;
		if ($index1 =~ /[A-Z]+/) {
			$kind = 'Chiral';
		} elsif ($index1 =~ /[a-z]+/) {
			$kind = 'AntiChiral';
		} else {
			die "Can't deserialize kind of index in $class";
		}

		return bless {
					
						kind => $kind,
						height => $height,
						index1 => $index1,
						index2 => $index2,
					
					}, $class;
		}

	sub print {
		my ($self) = @_;

		my $height_symbol;
		if ($self->height eq 'Upper') {
			$height_symbol = '^';
		} elsif ($self->height eq 'Lower') {
			$height_symbol = '_';
		} else {
			die "Can't understand height of index in printing of epsilon symbol";
		}

		return 'e'.$height_symbol.$self->index1.','.$self->index2;
	}
}

{
	# Импульс
	package PureMomentum;
	use base qw (Multiplicand);


	sub new {
		my ($class, $data) = @_;

		my ($lorentz_index, $momentum);
		if ($data =~ /^_([a-z]+?):::(.+)/) {
			($lorentz_index, $momentum) = ($1, $2);
		}

		return bless {
					
						lorentz_index => $lorentz_index,
						momentum => $momentum,
					
					}, $class;
		}

	sub print {
		my ($self) = @_;

		return '_'.$self->lorentz_index.':::'.$self->momentum;
	}
}

### ---------------------------------------------------------------------

{
	# Класс слагаемых
	package Summand;
	use base qw (Multiplicand);


	# Конструктор
	sub new {
		my ($class, $hash_ref) = @_;


		return bless {
					
						coef => $hash_ref->{coef},
						pointless => MultiplicandsArray->new(@{$hash_ref->{pointless}}),
						with_points => MultiplicandsArray->new(@{$hash_ref->{with_points}}),
					
					}, $class;
	}

	# Clone наследуется
	# Аксессоры к элементам получившегося объекта (по сути хеша) наследуются от Multiplicand (sic!)

	sub print {
		my ($self) = @_;

		return '('.$self->coef.')'.' x '.$self->pointless->print.' x '.$self->with_points->print;

	}

	# Чуть более хитрый сеттер - умножает сществующий коэффициент на аргумент сеттера и возвращает новый

	sub coef { 
		my ($self, $arg) = @_;

		if ($arg) { 
			$self->{coef} *= $arg;
		} 

		return $self->{coef};
	}

	# Подпрограмма по заданному слагаемому и киральности ищет свободный спинорный индекс (ближайший к началу алфавита)
	sub find_free_spinor_index {
		my ($self, $chirality) = @_;

		my @indices; # уже используемые индексы
		for (my $i = 0; $i < $self->pointless->size; $i++) {
			if (ref $self->pointless->element($i) eq 'SigmaMatrix') {
				push (@indices, $self->pointless->element($i)->index1) if ($chirality eq 'Chiral');
				push (@indices, $self->pointless->element($i)->index2) if ($chirality eq 'AntiChiral');
			} elsif (ref $self->pointless->element($i) eq 'EpsilonSymbol') {
				push (@indices, $self->pointless->element($i)->index1, $self->pointless->element($i)->index2) if ($chirality eq $self->pointless->element($i)->kind);
			} elsif (ref $self->pointless->element($i) eq 'PureMomentum') {
				next;
			}
		}
		for (my $i = 0; $i < $self->with_points->size; $i++) {
			for (my $j = 0; $j < $self->with_points->element($i)->dpart->size; $j++) {
				push @indices, $self->with_points->element($i)->dpart->element($j)->index if ($chirality eq $self->with_points->element($i)->dpart->element($j)->kind);
			}
		}

		@indices = sort @indices; # отсортируем их

		# теперь ищем свободный
		my $index;
		$index = 'A' if ($chirality eq 'Chiral');
		$index = 'a' if ($chirality eq 'AntiChiral');
		foreach my $current (@indices) {
			if ($index eq $current) {
				$index++;
				next;
			} else { 
				last;
			}
		}

		return $index;

	}

	# Подпрограмма по заданному слагаемому ищет свободный лоренцев индекс (ближайший к началу алфавита)
	sub find_free_lorentz_index {
		my ($self) = @_;

		my @indices; # уже используемые индексы
		for (my $i = 0; $i < $self->pointless->size; $i++) {
			if (ref $self->pointless->element($i) eq 'SigmaMatrix') {
				push (@indices, $self->pointless->element($i)->lorentz_index);
			} elsif (ref $self->pointless->element($i) eq 'PureMomentum') {
				push (@indices, $self->pointless->element($i)->lorentz_index);
			}
		}

		@indices = sort @indices; # отсортируем их

		# теперь ищем свободный
		my $index = 'a';
		foreach my $current (@indices) {
			if ($index eq $current) {
				$index++;
				next;
			} else { 
				last;
			}
		}

		return $index;

	}


	# Функция для опускания всех индексов слагаемого
	# ЗАМЕЧАНИЕ: КОЛИЧЕСТВО СОМНОЖИТЕЛЕЙ МЕНЯЕТСЯ ПОСЛЕ ВЫПОЛНЕНИЯ, ИБО ВПЕРЕД ВСТАВЛЯЮТСЯ ЭПСИЛОНЫ

	sub lower_index {
		my ($self) = @_;

		# Перебираем элементы массива dpart, ищем верхние индексы и, если находим, unshiftим e^A,B в массив multiplicands
		# идем по сомоножителям
		for (my $i = 0; $i < $self->with_points->size; $i++){
			for (my $j = 0; $j < $self->with_points->element($i)->dpart->size; $j++){

				if ($self->with_points->element($i)->dpart->element($j)->height eq 'Upper') {		
					$self->with_points->element($i)->dpart->element($j)->height('Lower');

					my $index_old = $self->with_points->element($i)->dpart->element($j)->index;
					my $index_new = $self->find_free_spinor_index ($self->with_points->element($i)->dpart->element($j)->kind);
					$self->with_points->element($i)->dpart->element($j)->index($index_new);

					$self->pointless->unshift_elem(EpsilonSymbol->new("e_$index_old,$index_new"))
				}
			}
		}

		return 1;
	}


}


{	# Класс-родитель для классов сомножителей без координаты и С координатой

	package MultiplicandsArray; 

	# Конструктор
	sub new {
		my ($class, @array_obj) = @_;

		return bless \@array_obj, $class;
	}

	sub clone {
		my ($self) = @_;
		my $class = ref $self;

		my @to_return;
		for (my $i = 0; $i < $self->size; $i++) {
			push @to_return, $self->element($i)->clone;
		}
		return bless \@to_return, $class;
	}

	# Аксессор к элементам получившегося объекта (по сути массива)
	sub element {
		my ($self, $element, $if_set, $obj_to_set) = @_;

		# Если есть в аргументах вызова конструктора строка set => Derivative->new ("..."), то есть сеттер
		if (defined ($if_set) and ($if_set eq 'set')) {
			$self->[$element] = $obj_to_set;
		}

		# Если есть в аргументах вызова конструктора строка delete => 4 -- удалим ее и вернем уже новый 4-ый (бывший 5-ый) (все остальыне элементы сдвинутся влево)
		if (defined ($if_set) and ($if_set eq 'delete')) {

			for (my $i = $element; $i<= @{$self} - 1; $i++) {
				$self->[$i] = $self->[$i+1];
			}
			pop @{$self};
		}

		return $self->[$element];
	}

	# Запрос на количество элементов
	sub size {
		my ($self) = @_;
		return $#{$self}+1;
	}

	sub unshift_elem {
		my ($self, $obj) = @_;

			unshift @{$self}, $obj;

		return $self->[0]; # возвращает этот новый объект
	}

	sub print {
		my ($self) = @_;
		my $to_print='';

		for (my $i = 0; $i < $self->size; $i++) {
			$to_print = $to_print.$self->element($i)->print.' x '; 
		}

		chop $to_print;
		chop $to_print;
		chop $to_print;

		return $to_print;

	}

}

			#################################
			#		Секция подпрограмм		#
			#################################

# Подпрограмма вывода каждого элемента полученного массива - применение к нему команды print и вывод всего на экран (еще знак + между слагаемыми)
sub print_sum {
	my @array = @_;

	print "\n ********** OUTPUT ********* \n";

	for(my $i = 0; $i < @array; $i++) {
		print $array[$i]->print;
		print " + " if ($i != $#array);
	}
	print "\n *********** END ********** \n";

	return 1;
}





			###################################
			#  Секция ввода начальных данных  #
			###################################

my @sum; # сумма всех слагаемых, обычный массив

$sum[0] = Summand->new (
	{
		coef => 2,
		pointless => [PureMomentum->new("_a:::p+l"),SigmaMatrix->new("sgm_AAbc^b"),EpsilonSymbol->new("e_AB,C"),RealSfield->new("V1:::m")],
		with_points => [  DiracDelta->new("dd1_2:::p+k", dpart=>"D2^A D2_b D1^a"), ChiralSfield->new ("f1:::p-k")  ], 
	}
);

$sum[1] = $sum[0]->clone;
say $sum[1]->with_points->element(0, 'delete')->print;
say $sum[1]->with_points->element(0)->dpart->unshift_der(derivative => "D1_A")->print;
say $sum[1]->with_points->element(0)->dpart->push_der(derivative => "D1^A")->print;
print_sum (@sum);

$sum[0]->coef($sum[0]->with_points->element(0)->index_align);
$sum[1]->coef($sum[1]->with_points->element(0)->index_align);
$sum[0]->lower_index;
print_sum (@sum);

say $sum[0]->with_points->element(0)->dpart->detect_D_cubed;

say $sum[0]->find_free_spinor_index ('Chiral');

say $sum[1]->find_free_lorentz_index;


			###################################
			#     		Секция кода   	     #
			###################################
