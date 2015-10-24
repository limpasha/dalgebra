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

		# Если есть в аргументах вызова конструктора строка object => Derivative->new ("..."), который подает только объект
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

		# Если есть в аргументах вызова конструктора строка object => Derivative->new ("..."), который подает только объект
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

### ---------------------------------------------------------------------------------------------------------- ###
### Не дифференцируемые сомножители (не зависящие от координат) и к тому же коммутирующие (грассманово четные) ###
### ---------------------------------------------------------------------------------------------------------- ###


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

{
	# Символ Кронекера
	package Kronecker;
	use base qw (Multiplicand);


	sub new {
		my ($class, $data) = @_;

		my ($lower_index, $upper_index);
		if ($data =~ /^krnck_([A-Za-z]+?)\^([A-Za-z]+?)$/) {
			($lower_index, $upper_index) = ($1, $2);
		}

		return bless {
					
						upper_index => $upper_index,
						lower_index => $lower_index,
					
					}, $class;
		}

	sub print {
		my ($self) = @_;

		return 'krnck_'.$self->lower_index.'^'.$self->upper_index;
	}
}


### ----------------------------------------------------------------------------------------------------- ###
###               Общий класс слагаемых и вспомогательный к нему класс MultiplicandsArray                 ###
### ----------------------------------------------------------------------------------------------------- ###

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

		my $to_return = '('.$self->coef.')'.' x ';
		$to_return .= $self->pointless->print.' x ' if ($self->pointless->print ne '');
		$to_return .= $self->with_points->print;

		return $to_return;

	}

	# Чуть более хитрый сеттер - умножает сществующий коэффициент на аргумент сеттера и возвращает новый

	sub coef { 
		my ($self, $arg) = @_;

		if ($arg) { 
			$self->{coef} *= $arg;
		} 

		return $self->{coef};
	}

	# Метод по заданному слагаемому и киральности ищет свободный спинорный индекс (ближайший к началу алфавита)
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

		# избавляемся от повторений в массиве @indices (чей-то алгоритм)
		my %seen = ();
		my @uniq =();
		foreach (@indices) {
			unless ($seen{$_}) {# Если мы попали сюда, значит, элемент не встречался ранее
				$seen{$_} = 1;
				push(@uniq, $_);
			}
		}

		# теперь ищем свободный
		my $index;
		$index = 'A' if ($chirality eq 'Chiral');
		$index = 'a' if ($chirality eq 'AntiChiral');
		foreach my $current (@uniq) {
			if ($index eq $current) {
				$index++;
				next;
			} else { 
				last;
			}
		}

		return $index;

	}

	# Метод по заданному слагаемому ищет свободный лоренцев индекс (ближайший к началу алфавита)
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

		# избавляемся от повторений в массиве @indices (чей-то алгоритм)
		my %seen = ();
		my @uniq =();
		foreach (@indices) {
			unless ($seen{$_}) {# Если мы попали сюда, значит, элемент не встречался ранее
				$seen{$_} = 1;
				push(@uniq, $_);
			}
		}

		# теперь ищем свободный
		my $index = 'a';
		foreach my $current (@uniq) {
			if ($index eq $current) {
				$index++;
				next;
			} else { 
				last;
			}
		}

		return $index;

	}


	# Метод для опускания всех индексов слагаемого
	# ЗАМЕЧАНИЕ: КОЛИЧЕСТВО СОМНОЖИТЕЛЕЙ МЕНЯЕТСЯ ПОСЛЕ ВЫПОЛНЕНИЯ, ИБО ВПЕРЕД ВСТАВЛЯЮТСЯ ЭПСИЛОНЫ (но в pointless-часть)

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
					$self->pointless->unshift_elem(EpsilonSymbol->new("e^$index_old,$index_new"))
				}
			}
		}

		return 1;
	}


}


{	# Класс-шаблон для классов сомножителей "без координаты"" и "с координатой"

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

		# Если есть в аргументах вызова конструктора строка set => ChiralSfield->new ("..."), то есть сеттер
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

	sub push_elem {
		my ($self, $obj) = @_;

			push @{$self}, $obj;

		return $self->[0]; # возвращает этот новый объект
	}	

	sub print {
		my ($self) = @_;
		my $to_print='';

		for (my $i = 0; $i < $self->size; $i++) {
			$to_print = $to_print.$self->element($i)->print;
			$to_print .= ' x ' if  ($self->element($i)->print ne '');
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
		print " + " if ($i != $#array); # чтобы не печатать знак + после последнего слагаемого
	}
	print "\n *********** END ********** \n";

	return 1;
}

# Функция для копирования элемента массива (если там сложная структура -- тогда вызов метода clone)
# Аргументы: (номер копируемого элемента, на какое место вставить-остальное сдвинуть вправо, ссылка на массив)

sub copy_array_element {
	my ($from, $to, $array_ref) = @_;

	for (my $i = $#$array_ref; $i >= $to; $i--) {
		$array_ref->[$i+1] = $array_ref->[$i];
	}
	$from++ if ($from > $to);

	# Если копируемые элемент - сложная стрктура, вызваем метод clone
	if (ref $array_ref->[$from]) {
		$array_ref->[$to] = $array_ref->[$from]->clone;		
	} else {
		$array_ref->[$to] = $array_ref->[$from];
	}

	return $array_ref->[$to]; # возврващает новый скопированный элемент

}

# Функция для удаления элемента из массива и сдвига всех его элементов влево, тем самым длина
# массива уменьшается на один элемент
# аргументы -- (ссылка на массив, индекс элемента)
# пример вызова del_array_element (\@array, 3)

sub del_array_element {

	# начинаем с данного i-ого элемента, копируем туда значение i+1 - ого элемента 

	for (my $i = $_[1]; $i<= @{$_[0]} - 1; $i++) {
		@{$_[0]}[$i] = @{$_[0]}[$i+1];
	}
	pop @{$_[0]};
}


### ----------------------------------------------------------------------------------------------------- ###
###          Общее семейство подпрограмм для вычислений с производными на дельта-функциях                 ###
### ----------------------------------------------------------------------------------------------------- ###



# Подпрограмма - коммутация сопряженных ковариантных производных вправо к дельта-функции,
# одновременно увеличивая количество слагаемых, вынося коэффициенты и помня, что D^n=0, n>=3
# ПУСТЬ ОН УЖЕ ВЫРОВНЕН ПО ТЕТА-ИНДЕКСУ И ИНДЕКСЫ ОПУЩЕНЫ
# Аргументы = (номер слагаемого, номер сомножителя в with_points, ссылка на массив @sum)

sub derivatives_commute {

	my ($summand, $multiplicand, $sum) = @_; # получаем номера слагаемого и сомножителя, а также ссылку на массив слагаемых
	
	# проверим, есть ли вообще производные, действующие на дельта-функцию. Если нет -- выход
	if ($sum->[$summand]->with_points->element($multiplicand)->dpart->size == 0) {
		return "nothing_to_do";
	}

	# Перебираем элементы массива dpart справа налево, ищем D со строчным индексом и,
	# если находим, антикоммутируем его. Для этого объявим дополнительные переменные:

	my $i; # счетчик
	my $prev_big_index; # запоминаем предыдущий большой индекс (от обычной D)
	my $curr_small_index; # запоминаем текущий маленький индекс (от D с чертой)

	my $lorentz_index; # лоренц-индекс, который будем приписывать импульсу и sgm_Ab^n

	my $previous = 2; # будем детектить, какой тип производной был на предыдущем шаге
			# если была D с чертой = 0, если просто D = 1  

	# вытащим для начала импульс из дельты
	my $momentum = $sum->[$summand]->with_points->element($multiplicand)->momentum; # сюда его сохраним

	# теперь пойдем по каждому элементу массива dpart
	for ($i = $sum->[$summand]->with_points->element($multiplicand)->dpart->size - 1; $i >= 0; $i--) {

		# проверим на D^3=0 и, если находим, то удаляем это слагаемое
		if ($sum->[$summand]->with_points->element($multiplicand)->dpart->detect_D_cubed){
			del_array_element ($sum, $summand);
			return "was_deleted"; # заканчиваем, потому что именно это слагаемое уже было обработано и удалено!
		}

		# ищем маленький (!) индекс у ковариантной производной и запоминаем его 
		# запоминаем тут же, кстати, признак предыдущего

		if ($sum->[$summand]->with_points->element($multiplicand)->dpart->element($i)->kind eq 'AntiChiral') {
			$curr_small_index = $sum->[$summand]->with_points->element($multiplicand)->dpart->element($i)->index;
			
			if ($previous == 2 || $previous == 0){
				$previous = 0;
				next; # если первый с конца- D с чертой или предыдущий был D с чертой -- сразу дальше
			} elsif ($previous == 1) {
				$sum->[$summand]->coef(-1); # записываем коэффициент от {,}=0
				
				# меняем местами две ковариантные производные в массиве dpart (чуть-чуть вмешаемся в стуктуру объекта dpart)
				($sum->[$summand]->with_points->element($multiplicand)->dpart->[$i], $sum->[$summand]->with_points->element($multiplicand)->dpart->[$i+1]) = ($sum->[$summand]->with_points->element($multiplicand)->dpart->[$i+1], $sum->[$summand]->with_points->element($multiplicand)->dpart->[$i]);

		# а тут нужно бы создать новое слагаемое (элемент массива summ)
		# скопировать туда dpart, удалив эти две производные
		# также скопировать значение коэффициента в новое, домножив его на (-2)
		# и еще добавить новых два сомножителя: sgm_${prev_big_index}$2^n и _n:::pprint "changed\n";

				copy_array_element($summand,$summand+1, $sum); # копируем слагаемое в соседнюю ячейку
				$sum->[$summand+1]->coef(2); # добавляем коэффициент *2 (-1 уже есть) из антикоммутатора

				# если D1_A D1_b dd2_1:::p, то вытаскиваемый импульс = -p, потому проверяем вторую точку дельта-функции, и если она совпадает с точкой производных -- домножить на -1 коэффициент
				$sum->[$summand+1]->coef(-1) if ($sum->[$summand+1]->with_points->element($multiplicand)->dpart->element($i)->point == $sum->[$summand]->with_points->element($multiplicand)->point2);

				# у нового слагаемого удаляем в dpart пару производных
				$sum->[$summand+1]->with_points->element($multiplicand)->dpart->element($i, 'delete'); # когда удалили одну, все сместилось
				$sum->[$summand+1]->with_points->element($multiplicand)->dpart->element($i, 'delete');
				
			# добавим еще и сигмы вместе с импульсом
			# импульс уже вытащили, он сидит в $momentum

				# сначала найдем свободный лоренцев индекс
				$lorentz_index = $sum->[$summand+1]->find_free_lorentz_index;

				$sum->[$summand+1]->pointless->unshift_elem(PureMomentum->new ("_${lorentz_index}:::$momentum"));
				$sum->[$summand+1]->pointless->unshift_elem(SigmaMatrix->new ("sgm_${prev_big_index}${curr_small_index}^$lorentz_index"));

				# а теперь включаем рекурсию - вызвываем функцию коммутации для	
				# summand+1-ого слагаемого, а в нем $multiplicand-ый сомножитель секции with_points
				# PS (в pointless добавились sgmAb^n и _n:::p)

				derivatives_commute($summand+1,$multiplicand, $sum);

				# тут подготавливаем перменные цикла для прохождения цикла снова!
				$previous = 2;
				$i = $sum->[$summand]->with_points->element($multiplicand)->dpart->size;
			}

	
		} elsif ($sum->[$summand]->with_points->element($multiplicand)->dpart->element($i)->kind eq 'Chiral') {
			$prev_big_index = $sum->[$summand]->with_points->element($multiplicand)->dpart->element($i)->index;
			$previous = 1; # в случае обнаружения простой D (без черты) -- метка
		}
	}

	return "good";

}

# Функция - перебрасывание внешней (самой левой) производной, действующей на сомножитель, по частям
# Аргументы = (номер слагаемого, номер сомножителя, ссылка на массив слагаемых)

sub byparts_ext_der {

	my ($summand, $multiplicand, $sum) = @_; # получаем номера слагаемого и сомножителя

	# проверим, есть ли вообще производные, действующие на сомножитель (обычно, дельта-функцию). Если нет -- выход
	if ($sum->[$summand]->with_points->element($multiplicand)->dpart->size == 0) {
		return "nothing_to_do";
	}
	
	my $derivative = $sum->[$summand]->with_points->element($multiplicand)->dpart->element(0)->clone; # запоминаем внешнюю производную, которую собираемся перебрасывать по частям
	$sum->[$summand]->with_points->element($multiplicand)->dpart->element(0, 'delete'); # удаляем ее теперь из массива dpart текущего сомножителя

	## далее будем вставлять новые слагаемые (правило Лейбница) с учетом ЗНАКА!

	my $skip = 0; # считаем количество пропущенных сомножителей (которые могли бы быть, но из зануляет производная)
	my $how_many_summands_stayed_alive = $sum->[$summand]->with_points->size-1;


	# поехали: [1-ый блок] сначала идем по сомножителям: от текущего+1 до последнего=(колич. сомножителей-1)
	# такой порядок этих двух блоков потому, что вставляется слагаемое сразу же за текущим - удобнее читать
	for (my $i = $multiplicand + 1; $i < $sum->[$summand]->with_points->size; $i++) {
		
		## если индекс производной не равен одному из индексов сомножителя, на который будет действовать -- удалить такое слагаемое (просто не создавать)
			# для НЕ дельта-функций проверка
			if ((ref $sum->[$summand]->with_points->element($i) ne 'DiracDelta') and ($derivative->point != $sum->[$summand]->with_points->element($i)->point)) {
				$skip++;
				next;
			}
			# Проверка ДЛЯ дельта-функций (так как у нее 2 точки)
			if ((ref $sum->[$summand]->with_points->element($i) eq 'DiracDelta') and ($derivative->point != $sum->[$summand]->with_points->element($i)->point1) and ($derivative->point != $sum->[$summand]->with_points->element($i)->point2) ) {
				$skip++;
				next;
			}
			# Еще учет киральности
			if ((ref $sum->[$summand]->with_points->element($i) eq 'ChiralSfield') and ($sum->[$summand]->with_points->element($i)->dpart->size == 0) and ($sum->[$summand]->with_points->element($i)->kind ne $derivative->kind) ){
				$skip++;
				next;
			}

		copy_array_element($summand, $summand+1, $sum); # копируем слагаемое в соседнюю ячейку
		
		# посчитаем количество производных, сквозь которые проходит оператор до $i-ого
		my $count; # счетчик
		my $total = $sum->[$summand]->with_points->element($multiplicand)->dpart->size; # количество D
		for ($count = $multiplicand + 1; $count < $i; $count++) {
			$total += $sum->[$summand]->with_points->element($count)->dpart->size;
		}

		$sum->[$summand+1]->coef((-1)**($total+1)); # добавляем коэффициент
		$sum->[$summand+1]->with_points->element($i)->dpart->unshift_der(object => $derivative); # вставляем новую производную в массив dpart нового слагаемого
	}

	# продолжаем [2-ой блок]:  теперь идем по сомножителям: от нулевого до текущего-1
	for (my $i = 0; $i < $multiplicand; $i++) {
	
		## если индекс производной не равен одному из индексов сомножителя, на который будет действовать -- удалить такое слагаемое (просто не создавать)
			# для НЕ дельта-функций провекра
			if ((ref $sum->[$summand]->with_points->element($i) ne 'DiracDelta') and ($derivative->point != $sum->[$summand]->with_points->element($i)->point)) {
				$skip++;
				next;
			}
			# Проверка ДЛЯ дельта-функций (так как у нее 2 точки)
			if ((ref $sum->[$summand]->with_points->element($i) eq 'DiracDelta') and ($derivative->point != $sum->[$summand]->with_points->element($i)->point1) and ($derivative->point != $sum->[$summand]->with_points->element($i)->point2) ) {
				$skip++;
				next;
			}
			# Еще учет киральности
			if ((ref $sum->[$summand]->with_points->element($i) eq 'ChiralSfield') and ($sum->[$summand]->with_points->element($i)->dpart->size == 0) and ($sum->[$summand]->with_points->element($i)->kind ne $derivative->kind) ){
				$skip++;
				next;
			}

		copy_array_element($summand, $summand+1, $sum); # копируем слагаемое в соседнюю ячейку
		
		# посчитаем количество производных, сквозь которые проходит оператор до $i-ого
		my $count; # счетчик
		my $total = 0; # количество D
		for ($count = $multiplicand - 1; $count >= $i; $count--) {
			$total += $sum->[$summand]->with_points->element($count)->dpart->size;
		}

		$sum->[$summand+1]->coef((-1)**($total+1)); # добавляем коэффициент
		$sum->[$summand+1]->with_points->element($i)->dpart->unshift_der(object => $derivative); # вставляем новую производную в массив dpart нового слагаемого
	}

	# теперь удаляем само слагаемое, из которого всё и пошло
	del_array_element ($sum, $summand);

	$how_many_summands_stayed_alive -= $skip; # количество выживших слагаемых = (количество_сомножителей - 1) - количество_пропущенных_потенциальных_слагаемых
	return $how_many_summands_stayed_alive;
}


# Функция -- вычисление выражений с голой дельта-функцией и/или двумя дельта-функциями по краям
# У дельта-функций одинаковый набот тета-индексов (dd1_2 и dd2_1, например)
# в ином случае - интегрирование этой дельта-функции и замена бОльшего индекса на меньший у всех
# сомножителей этого конкретного слагаемого
# Аргументы =  (номер слагаемого, ссылка на массив слагаемых)
# P.S Правильно будет пускать только на "прокоммутированное на D с чертой в право" слагаемое

sub two_delta_one_naked {

	my ($summand, $sum) = @_; # номер слагаемого и ссылка на массив слагаемых

	## Сначала отыщем голую дельта-функцию
	my ($index1, $index2) = (0, 0); # тета-индексы дельта-функции
	my $multiplicand; # номер сомножителя с голой дельта-функцией

	for (my $i = 0; $i < $sum->[$summand]->with_points->size; $i++) {
		if (ref $sum->[$summand]->with_points->element($i) eq 'DiracDelta') {
			if ($sum->[$summand]->with_points->element($i)->dpart->size == 0) {

				$index1 = $sum->[$summand]->with_points->element($i)->point1;
				$index2 = $sum->[$summand]->with_points->element($i)->point2;
				$multiplicand = $i;
			}
		}
	}

	if (! defined ($multiplicand)) { # не нашли после всей операции выше
#		print "В $summand-ом слагаемом нет голых дельта-функций \n";
		return "nothing_to_do";
	}

	## Теперь ищем дельта-функцию с такими же тета-индексами (главное не наткнуться на себя же)
	for (my $i = 0; $i < $sum->[$summand]->with_points->size; $i++) {
		if ($i == $multiplicand) { # чтобы не наткнуться на ту же дельту ("голую")
			$i++;
		}

		# Проверяем, если это дельта-функция и у нее есть оба индекса, таких же, как и у голой
		if ((ref $sum->[$summand]->with_points->element($i) eq 'DiracDelta' ) and (($sum->[$summand]->with_points->element($i)->point1 == $index1 and $sum->[$summand]->with_points->element($i)->point2 == $index2) or 
			($sum->[$summand]->with_points->element($i)->point2 == $index1 and $sum->[$summand]->with_points->element($i)->point1 == $index2))) {

			if ($sum->[$summand]->with_points->element($i)->dpart->size <= 3) { # то есть dd DDD dd и меньше - удалить слагаемое
				del_array_element($sum,$summand);
				return "was_deleted";
				
			} elsif ($sum->[$summand]->with_points->element($i)->dpart->size == 4) { # если dd DDDD dd =4e_AB e_ab dd
				# соберем все индексы у ковариантных производных
				my @temp = (); # сюда

				for (my $j = 0; $j < $sum->[$summand]->with_points->element($i)->dpart->size; $j++){
					push @temp, $sum->[$summand]->with_points->element($i)->dpart->element($j)->index;
				}

				# удалим лучше этот сомножитель
				$sum->[$summand]->with_points->element($i, 'delete');
				$sum->[$summand]->coef(4);	# коэффициент умножаем на 4
				
				# Вставляем в начало два эпсилона
				$sum->[$summand]->pointless->unshift_elem(EpsilonSymbol->new("e_$temp[0],$temp[1]"));
				$sum->[$summand]->pointless->unshift_elem(EpsilonSymbol->new("e_$temp[3],$temp[2]"));

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
	$sum->[$summand]->with_points->element($multiplicand, 'delete'); # сначала ее "проинтегрируем"-удалим
	
	# пойдем по сомножителям
	for (my $i = 0; $i < $sum->[$summand]->with_points->size; $i++) {
			## замена в секции сомножителей с точкой

		# Если $i-ый сомножитель - киральное суперполе или вещественное скалярное суперполе, причем его точка == $index2, то заменить ее на $index1
		if (((ref $sum->[$summand]->with_points->element($i) eq 'ChiralSfield') or (ref $sum->[$summand]->with_points->element($i) eq 'RealSfield') ) and ($sum->[$summand]->with_points->element($i)->point == $index2)) {
			$sum->[$summand]->with_points->element($i)->point($index1);
		}
		# Если $i-ый сомножитель - дельта-функция, причем какая-либо его точка == $index2, то заменить ее на $index1
		if ((ref $sum->[$summand]->with_points->element($i) eq 'DiracDelta') and ($sum->[$summand]->with_points->element($i)->point1 == $index2)) {
			$sum->[$summand]->with_points->element($i)->point1($index1);
		}
		if ((ref $sum->[$summand]->with_points->element($i) eq 'DiracDelta') and ($sum->[$summand]->with_points->element($i)->point2 == $index2)) {
			$sum->[$summand]->with_points->element($i)->point2($index1);
		}

			## замена в секции dpart каждого из них

		for (my $j = 0; $j < $sum->[$summand]->with_points->element($i)->dpart->size; $j++) {
			# Если точка производной совспадает с $index2, то заменим ее на $index1
			if ($sum->[$summand]->with_points->element($i)->dpart->element($j)->point == $index2) {
				$sum->[$summand]->with_points->element($i)->dpart->element($j)->point($index1);
			}
		}


	}
	return "good";
}

# Функция поиска дельта-функций в слагаемом и вывод их позиций (номера сомножителя) в виде упорядоченного по объему dpart списка
# Аргументы = (номер слагаемого, ссылка на массив слагаемых)

sub find_delta {

	my ($summand, $sum) = @_; # считали номер слагаемого и ссылку на массив слагаемых
	my @found_dd; # сюда будем записывать номера сомножителей-дельта-функций

	# идем по сомножителям
	for(my $i = 0; $i < $sum->[$summand]->with_points->size; $i++) {
		if (ref $sum->[$summand]->with_points->element($i) eq 'DiracDelta') { # если нашли дельта-функцию сомножителем
			# если количество дельта-функций в ней меньше, чем в 0-ом элементе @found_dd
			# то помещаем ее индекс на нулевое место: т.о. $found_dd[0]-индекс сомножителя с наименьшим количеством производных
			if ($found_dd[0] and ($sum->[$summand]->with_points->element($i)->dpart->size < $sum->[$summand]->with_points->element($found_dd[0])->dpart->size)) {
				unshift (@found_dd, $i);
			} else {
				push (@found_dd, $i);
			}
		}
	}

	return @found_dd;
}

# Функция - цикл полной отработки слагаемого (избавления от дельта-функций)
# Аргументы = (номер слагаемого, ссылка на массив слагаемых)
# PS генерит новые слагаемые после себя (не обработанные этим же workout_summand_deltas'ом!)

sub workout_summand_deltas {

	my ($summand, $sum) = @_; # считали номер слагаемого и ссылку на массив слагаемых

	while ( (my @deltas = find_delta($summand, $sum)) != 0 ) { # пока еще есть дельта-функции в слагаемом (записываем их в @deltas - временное хранилище индексов)

		# СНАЧАЛА все-таки производим упрощение выражений с дельта-функцией у всего слагамого: в цикле для каждого сомножителя, на котором есть дельты (для того, чтобы оставшиеся от byparts_ext_der слагаемые не были абы-какими в плане структуры их dpart)
		foreach my $multiplicand (@deltas) {
			return "was_deleted" if (derivatives_commute($summand, $multiplicand, $sum) eq "was_deleted"); # был удален при коммутировании производной (из-за D^3)
		}

		# Продолжаем, если не return'улся на предыдущем шаге
		@deltas = find_delta($summand, $sum);
		my $dd_with_min_D = $deltas[0]; # запишем индекс дельта-функции с min числом D

		# перебрасываем по частям производную с этого сомножителя на другие => появляются другие слагаемые справа (!), о них не заботимся в этой итерации цикла, они будут обработаны в следующем вызове всей нашей подпрограммы workout_summand_deltas
		return "was_deleted" unless byparts_ext_der($summand, $dd_with_min_D, $sum);

		# далее производим упрощение выражений с дельта-функцией у всего слагамого: в цикле для каждого сомножителя, на котором есть дельты
		foreach my $multiplicand (@deltas) {
			return "was_deleted" if (derivatives_commute($summand, $multiplicand, $sum) eq "was_deleted"); # был удален при коммутировании производной (из-за D^3)
		}

		# теперь проверяем на наличие "голой" дельта-функции, и, если найдем, интегрируем ее
		return "was_deleted" if (two_delta_one_naked($summand, $sum) eq "was_deleted"); # выходим из цикла, если слагаемое было удалено (из-за dd DDD dd, наверное)
	}
}



### ----------------------------------------------------------------------------------------------------- ###
###              Общее семейство подпрограмм для вычислений с производными на полях f и F                 ###
### ----------------------------------------------------------------------------------------------------- ###



# Функция -- проверка существования "D с чертой" в dpart
# аргументы - (номер слагаемого, номер сомножителя в multiplicands, сслыка на массив слагаемых)
# возвращает 0, если "нет D с чертой" в dpart (или их количество)

sub isthere_D_bar {
	
	my ($summand, $multiplicand, $sum) = @_; # получаем номера слагаемого и сомножителя
	my $result = 0; # сюда будем прибавлять единичку, если найдем "D с чертой"

	for(my $i = 0; $i < $sum->[$summand]->with_points->element($multiplicand)->dpart->size; $i++) {
		$result++ if ($sum->[$summand]->with_points->element($multiplicand)->dpart->element($i)->kind eq 'AntiChiral');
	}
	return $result;
}


# Функция - коммутация сопряженных ковариантных производных вправо к ПОЛЮ (!) F (не сопряженному),
# одновременно увеличивая количество слагаемых, вынося коэффициенты и помня, что D^n=0, n>=3
# а также пользуясь киральностью поля: D1_a F = 0;
# аргументы = (номер слагаемого, номер сомножителя в multiplicands, ссылка на массив слагаемых)

sub derivatives_commute_fields {
	my ($summand, $multiplicand, $sum) = @_; # получаем номера слагаемого и сомножителя, а также ссылку на массив слагаемых

	# проверим, есть ли вообще производные, действующие на ПОЛЕ. Если нет -- выход
	if ($sum->[$summand]->with_points->element($multiplicand)->dpart->size == 0) {
		return "nothing_to_do";
	}

	# Перебираем элементы массива dpart справа налево, ищем D со строчным индексом (AntiChiral) и,
	# если находим, антикоммутируем его. Для этого объявим дополнительные переменные:

	my $prev_big_index; # запоминаем предыдущий большой индекс (от обычной D)
	my $curr_small_index; # запоминаем текущий маленький индекс (от D с чертой)
	my $lorentz_index; # лоренц-индекс, который будем приписывать импульсу и sgm_Ab^n

	# вытащим для начала импульс из ПОЛЯ
	my $momentum = $sum->[$summand]->with_points->element($multiplicand)->momentum; # сюда его сохраним

	# теперь пойдем по каждому элементу массива dpart
	for (my $i = $sum->[$summand]->with_points->element($multiplicand)->dpart->size - 1; $i >= 0; $i--) {

		if ($sum->[$summand]->with_points->element($multiplicand)->dpart->detect_D_cubed) { # проверим на D^3=0 и, если находим, то удаляем это слагаемое
			del_array_element($sum,$summand);
			return "was_deleted";

		} elsif ($sum->[$summand]->with_points->element($multiplicand)->dpart->element(-1)->kind eq 'AntiChiral') { # проверим, может уже "D с чертой" стоит справа? Если так - удалить summand!
			del_array_element($sum,$summand);
			return "was_deleted";

		} elsif (!isthere_D_bar($summand,$multiplicand,$sum)) { # а может "D с чертой" в dpart вообще нет? Если так, то выход.		
			return "nothing_to_do";
		}


	# ищем маленький (!) индекс и запоминаем его 
	# запоминаем тут же, кстати, признак предыдущего
		if ($sum->[$summand]->with_points->element($multiplicand)->dpart->element($i)->kind eq 'AntiChiral') {
			$curr_small_index = $sum->[$summand]->with_points->element($multiplicand)->dpart->element($i)->index;
				
			$sum->[$summand]->coef(-1); # записываем коэффициент от {,}=0

			# меняем местами две ковариантные производные в массиве dpart (чуть-чуть вмешаемся в стуктуру объекта dpart)
			($sum->[$summand]->with_points->element($multiplicand)->dpart->[$i], $sum->[$summand]->with_points->element($multiplicand)->dpart->[$i+1]) = ($sum->[$summand]->with_points->element($multiplicand)->dpart->[$i+1], $sum->[$summand]->with_points->element($multiplicand)->dpart->[$i]);


	# а тут нужно бы создать новое слагаемое (элемент массива @$sum)
	# скопировать туда dpart, удалив эти две производные
	# также скопировать значение coef в новое, домножив его на (-2)
	# и еще добавить новых два сомножителя: sgm_${prev_big_index}$2^n и _n:::p;

			copy_array_element($summand,$summand+1, $sum); # копируем слагаемое в соседнюю ячейку
			$sum->[$summand+1]->coef(2); # добавляем коэффициент *2 (-1 уже есть) из антикоммутатора

			# у нового слагаемого удаляем в dpart пару производных
			$sum->[$summand+1]->with_points->element($multiplicand)->dpart->element($i, 'delete'); # когда удалили одну, все сместилось
			$sum->[$summand+1]->with_points->element($multiplicand)->dpart->element($i, 'delete');

		# добавим еще и сигмы вместе с импульсом
		# импульс уже вытащили, он сидит в $momentum

			# сначала найдем свободный лоренцев индекс
			$lorentz_index = $sum->[$summand+1]->find_free_lorentz_index;

			$sum->[$summand+1]->pointless->unshift_elem(PureMomentum->new ("_${lorentz_index}:::$momentum"));
			$sum->[$summand+1]->pointless->unshift_elem(SigmaMatrix->new ("sgm_${prev_big_index}${curr_small_index}^$lorentz_index"));

			# а теперь включаем рекурсию - вызвываем функцию коммутации для	
			# summand+1-ого слагаемого, а в нем $multiplicand-ый сомножитель секции with_points
			# PS (в pointless добавились sgmAb^n и _n:::p)

			derivatives_commute_fields($summand+1,$multiplicand, $sum);

			# тут подготавливаем перменные цикла для прохождения цикла снова!
			$i = $sum->[$summand]->with_points->element($multiplicand)->dpart->size;

	
		} elsif ($sum->[$summand]->with_points->element($multiplicand)->dpart->element($i)->kind eq 'Chiral') {
			$prev_big_index = $sum->[$summand]->with_points->element($multiplicand)->dpart->element($i)->index;
		}
	}
	return "good";
}


# Функция поиска поля f/F в слагаемом и вывод его позиций (номера сомножителя)
# Аргументы = (номер слагаемого, тип поля [Chiral (F) или AntiChiral (f)], ссылка на массив слагаемых)

sub find_field {

	my ($summand, $field_kind, $sum) = @_; # считали номер слагаемого из входа

	# идем по сомножителям
	for(my $i = 0; $i <= $sum->[$summand]->with_points->size-1; $i++) {
		if ((ref $sum->[$summand]->with_points->element($i) eq 'ChiralSfield') and ($sum->[$summand]->with_points->element($i)->kind eq $field_kind) ) { # если нашли поле сомножителем
			return $i;
		}
	}

	return -1; # в случае, если не нашли
}

# Функция полной отработки слагаемого: убрать производные на полях
# сначала по частям перебрасываем ВСЕ их с f на F, затем derivatives_commute_fields -- остаток=0, то есть если остались на F еще производные (только D без черты могут) -- тут просто проверить объем dpart
# аргументы = (номер слагаемого, ссылка на массив слагаемых)

sub workout_summand_fields {

	my ($summand, $sum) = @_;

	my $index_f = find_field($summand, "AntiChiral", $sum); # индекс поля f
	my $index_F = find_field($summand, "Chiral", $sum); # индекс поля F

	# перебрасываем ВСЕ производные с поля f на поле F
	while ($sum->[$summand]->with_points->element($index_f)->dpart->size) {
	
		return "was_deleted" unless byparts_ext_der($summand, $index_f, $sum);
		return "was_deleted" if (derivatives_commute_fields($summand,$index_F, $sum) eq "was_deleted");
		#$index_f = find_field($summand, "AntiChiral", $sum);
		#$index_F = find_field($summand, "Chiral", $sum); 
	}

	# теперь коммутируем производные в сомножителе DD F (если они уже были на поле F и появились там НЕ в результате перебрасывания производной)
	return "was_deleted" if (derivatives_commute_fields($summand,$index_F, $sum) eq "was_deleted");

	# если остались производные - удалить слагаемое (ибо остались по видимому без черты DF*f, где DF !=0, но если переборость производную -> -F*Df=0!)
	if ($sum->[$summand]->with_points->element($index_F)->dpart->size) {
		del_array_element($sum,$summand);
		return "was_deleted";
	}

	return "good";
}



### ----------------------------------------------------------------------------------------------------- ###
###                  Общее семейство подпрограмм для вычислений сверток эпсилон-символов                  ###
### ----------------------------------------------------------------------------------------------------- ###

# Функция свертки эпсилон-символов друг с другом (с нижними индексами и с верхними)
# сначала находим эпсилоны с нижними индексами, затем ищем эпсилон с хотя бы одним совпадающим верхним и заменяем их оба на Кронекера
# аргументы = (номер слагаемого, ссылка на массив слагаемых)

sub epsilon_convolution {

	my ($summand, $sum) = @_;

	# Будем идти по сомножителям и искать эпсилоны с нижними индексами
	for (my $i = 0; $i < $sum->[$summand]->pointless->size; $i++) {

		# Если нашли:
		if ((ref $sum->[$summand]->pointless->element($i) eq 'EpsilonSymbol') and ($sum->[$summand]->pointless->element($i)->height eq 'Lower')) {
		
			# Будем искать эпсилон уже с ВЕРХНИМИ индексами (такими же!)
			for (my $j = 0; $j < $sum->[$summand]->pointless->size; $j++) {
				# Если нашли
				if ((ref $sum->[$summand]->pointless->element($j) eq 'EpsilonSymbol') and ($sum->[$summand]->pointless->element($j)->height eq 'Upper') ) {

					if ($sum->[$summand]->pointless->element($j)->index1 eq $sum->[$summand]->pointless->element($i)->index1) {
						my ($lower_index, $upper_index) = ($sum->[$summand]->pointless->element($i)->index2, $sum->[$summand]->pointless->element($j)->index2);
						
						my ($left, $right) = ($i, $j);
						($left, $right) = ($right, $left) if ($right < $left);
						$sum->[$summand]->pointless->element($right, 'delete');
						$sum->[$summand]->pointless->element($left, 'delete');

						$sum->[$summand]->pointless->unshift_elem (Kronecker->new("krnck_$lower_index^$upper_index"));
						$sum->[$summand]->coef(-1);
						last;
					}
					if ($sum->[$summand]->pointless->element($j)->index1 eq $sum->[$summand]->pointless->element($i)->index2) {
						my ($lower_index, $upper_index) = ($sum->[$summand]->pointless->element($i)->index1, $sum->[$summand]->pointless->element($j)->index2);
						
						my ($left, $right) = ($i, $j);
						($left, $right) = ($right, $left) if ($right < $left);
						$sum->[$summand]->pointless->element($right, 'delete');
						$sum->[$summand]->pointless->element($left, 'delete');						
						
						$sum->[$summand]->pointless->unshift_elem (Kronecker->new("krnck_$lower_index^$upper_index"));
						last;
					}
					if ($sum->[$summand]->pointless->element($j)->index2 eq $sum->[$summand]->pointless->element($i)->index1) {
						my ($lower_index, $upper_index) = ($sum->[$summand]->pointless->element($i)->index2, $sum->[$summand]->pointless->element($j)->index1);
				
						my ($left, $right) = ($i, $j);
						($left, $right) = ($right, $left) if ($right < $left);
						$sum->[$summand]->pointless->element($right, 'delete');
						$sum->[$summand]->pointless->element($left, 'delete');

						$sum->[$summand]->pointless->unshift_elem (Kronecker->new("krnck_$lower_index^$upper_index"));
						last;				
					}
					if ($sum->[$summand]->pointless->element($j)->index2 eq $sum->[$summand]->pointless->element($i)->index2) {
						my ($lower_index, $upper_index) = ($sum->[$summand]->pointless->element($i)->index1, $sum->[$summand]->pointless->element($j)->index1);
						
						my ($left, $right) = ($i, $j);
						($left, $right) = ($right, $left) if ($right < $left);
						$sum->[$summand]->pointless->element($right, 'delete');
						$sum->[$summand]->pointless->element($left, 'delete');		

						$sum->[$summand]->coef(-1);						
						$sum->[$summand]->pointless->unshift_elem (Kronecker->new("krnck_$lower_index^$upper_index"));
						last;						
					}

				}
			}
		}
	}

	return "good";
}


# Функция свертки кронекеров
# аргументы = (номер слагаемого, ссылка на массив слагаемых)

sub kronecker_convolution {

	my ($summand, $sum) = @_;

	# Будем идти по сомножителям и искать кронекеры
BIG: for (my $i = 0; $i < $sum->[$summand]->pointless->size; $i++) {

		# Если нашли:
		if ( ref $sum->[$summand]->pointless->element($i) eq 'Kronecker' ) {
		
			# Будем искать теперь сомножители в pointless-части слагаемого с такими же индексами
			for (my $j = 0; $j < $sum->[$summand]->pointless->size; $j++) {
				# Если нашли сигма-матрицу
				if ( ref $sum->[$summand]->pointless->element($j) eq 'SigmaMatrix' ) {

					# Совпал первый индекс
					if ($sum->[$summand]->pointless->element($j)->index1 eq $sum->[$summand]->pointless->element($i)->upper_index) {

						my $index_to_replace = $sum->[$summand]->pointless->element($i)->lower_index;
						# Заменяем его
						$sum->[$summand]->pointless->element($j)->index1($index_to_replace);
						# Теперь удалим кронекер
						$sum->[$summand]->pointless->element($i, 'delete');
						redo BIG;
					}
					# Совпал второй индекс
					if ($sum->[$summand]->pointless->element($j)->index2 eq $sum->[$summand]->pointless->element($i)->upper_index) {

						my $index_to_replace = $sum->[$summand]->pointless->element($i)->lower_index;
						# Заменяем его
						$sum->[$summand]->pointless->element($j)->index2($index_to_replace);
						# Теперь удалим кронекер
						$sum->[$summand]->pointless->element($i, 'delete');
						redo BIG;
					}

				}
				# Если нашли эпсилон

				if ( ref $sum->[$summand]->pointless->element($j) eq 'EpsilonSymbol' ) {

					# Совпал первый индекс c верхним кронекеровским
					if ($sum->[$summand]->pointless->element($j)->index1 eq $sum->[$summand]->pointless->element($i)->upper_index) {

						my $index_to_replace = $sum->[$summand]->pointless->element($i)->lower_index;
						# Заменяем его
						$sum->[$summand]->pointless->element($j)->index1($index_to_replace);
						# Теперь удалим кронекер
						$sum->[$summand]->pointless->element($i, 'delete');
						redo BIG;
					}
					# Совпал второй индекс с верхним кронекеровским
					if ($sum->[$summand]->pointless->element($j)->index2 eq $sum->[$summand]->pointless->element($i)->upper_index) {

						my $index_to_replace = $sum->[$summand]->pointless->element($i)->lower_index;
						# Заменяем его
						$sum->[$summand]->pointless->element($j)->index2($index_to_replace);
						# Теперь удалим кронекер
						$sum->[$summand]->pointless->element($i, 'delete');
						redo BIG;
					}
					# Совпал первый индекс c нижним кронекеровским
					if ($sum->[$summand]->pointless->element($j)->index1 eq $sum->[$summand]->pointless->element($i)->lower_index) {

						my $index_to_replace = $sum->[$summand]->pointless->element($i)->upper_index;
						# Заменяем его
						$sum->[$summand]->pointless->element($j)->index1($index_to_replace);
						# Теперь удалим кронекер
						$sum->[$summand]->pointless->element($i, 'delete');
						redo BIG;
					}
					# Совпал второй индекс с нижним кронекеровским
					if ($sum->[$summand]->pointless->element($j)->index2 eq $sum->[$summand]->pointless->element($i)->lower_index) {

						my $index_to_replace = $sum->[$summand]->pointless->element($i)->upper_index;
						# Заменяем его
						$sum->[$summand]->pointless->element($j)->index2($index_to_replace);
						# Теперь удалим кронекер
						$sum->[$summand]->pointless->element($i, 'delete');
						redo BIG;
					}
				}
				# Если нашли кронекер (можно себя, можно другого)
				if ( ref $sum->[$summand]->pointless->element($j) eq 'Kronecker' ) {

					# Совпал верхний и нижний индексы найденного с верхним и нижним эталонного (то есть нашел сам себя)
					if ($i == $j) {
						# если с собой ничего нельзя поделать (то есть разные индексы)
						next if ($sum->[$summand]->pointless->element($j)->lower_index ne $sum->[$summand]->pointless->element($j)->upper_index);
						# удалим кронекер
						$sum->[$summand]->pointless->element($i, 'delete');

						$sum->[$summand]->coef(2);
						redo BIG;
					}

					# Совпал нижний индекс найденного с верхним эталонного
					if ($sum->[$summand]->pointless->element($j)->lower_index eq $sum->[$summand]->pointless->element($i)->upper_index) {

						my $index_to_replace = $sum->[$summand]->pointless->element($i)->lower_index;
						# Заменяем его
						$sum->[$summand]->pointless->element($j)->lower_index($index_to_replace);
						# Теперь удалим кронекер
						$sum->[$summand]->pointless->element($i, 'delete');
						redo BIG;
					}
					# Совпал верхний индекс найденного с нижним эталонного
					if ($sum->[$summand]->pointless->element($j)->upper_index eq $sum->[$summand]->pointless->element($i)->lower_index) {

						my $index_to_replace = $sum->[$summand]->pointless->element($i)->upper_index;
						# Заменяем его
						$sum->[$summand]->pointless->element($j)->upper_index($index_to_replace);
						# Теперь удалим кронекер
						$sum->[$summand]->pointless->element($i, 'delete');
						redo BIG;
					}

				}

			}
		}
	}

	return "good";
}


			###################################
			#  Секция ввода начальных данных  #
			###################################

#my @sum; # сумма всех слагаемых, обычный массив

#$sum[0] = Summand->new (
#	{
#		coef => 1,
#		pointless => [],
#		with_points => [ ChiralSfield->new ("F1:::-p"),  DiracDelta->new("dd1_2:::p+k1", dpart=>"D1^A D1_A D2_a D2^a"), DiracDelta->new("dd2_1:::p+k1+k2", dpart=>"D2^B D2_B D1_b D1^b"), DiracDelta->new("dd1_2:::p+k2", dpart=>"D1^C D1_C D2_c D2^c"), ChiralSfield->new ("f2:::p") ], 
#	}
#); 


			###################################
			#     		Секция кода   	     #
			###################################

say "Тестовый прогон:";
my @sum2;
$sum2[0] = Summand->new (
	{
		coef => 1,
		pointless => [],
		with_points => [ ChiralSfield->new ("F1:::-p"), DiracDelta->new("dd1_2:::k"), DiracDelta->new("dd1_4:::p-k", dpart => "D1^A D1_A D4_a D4^a"), DiracDelta->new("dd2_3:::l", dpart => "D2_b D2^b D3^B D3_B"),  DiracDelta->new("dd2_3:::k-l", dpart => "D2^C D2_C D3_c D3^c"), DiracDelta->new("dd3_4:::k"),ChiralSfield->new("f4:::-p")], 
	}
); 
say "Было:";
print_sum (@sum2);

say "Выравниваем индекс у 0-ого слагаемого 2-ого, 3-ого и 4-ого сомножителей (дельта-функций)";
$sum2[0]->coef($sum2[0]->with_points->element(2)->index_align);
$sum2[0]->coef($sum2[0]->with_points->element(3)->index_align);
$sum2[0]->coef($sum2[0]->with_points->element(4)->index_align);
print_sum (@sum2);

say "Опускаем индексы у 0-ого слагаемого";
$sum2[0]->lower_index;
print_sum (@sum2);

say "Избавляемся от голых дельта-функций";
say two_delta_one_naked(0,\@sum2);
say two_delta_one_naked(0,\@sum2);
say two_delta_one_naked(0,\@sum2);
say two_delta_one_naked(0,\@sum2);
print_sum (@sum2);

say "Скоммутируем производные у 0-ого слагаемого 2-его сомножителя (дельта-функций)";
derivatives_commute(0, 2, \@sum2);
print_sum (@sum2);

say "Запускаем ЦИКЛ WORKOUT-ов дельта-функций: ";
for (my $counter = 0; $counter < @sum2; $counter++){
	$counter-- if (workout_summand_deltas ($counter, \@sum2) eq "was_deleted");
}
print_sum (@sum2);

say "Запускаем ЦИКЛ WORKOUT-ов полей:";
for (my $counter = 0; $counter < @sum2; $counter++){
	$counter-- if (workout_summand_fields($counter, \@sum2) eq "was_deleted");
}
print_sum (@sum2);

say "Свернем все индексы (эпсилоны с верхними и нижними, а также кронекеры):";
for (my $counter = 0; $counter < @sum2; $counter++){
	epsilon_convolution($counter, \@sum2);
}
for (my $counter = 0; $counter < @sum2; $counter++){
	kronecker_convolution($counter, \@sum2);
}
print_sum (@sum2);



__END__


		# Продолжаем, если не return'улся на предыдущем шаге
		my @deltas = find_delta(0, \@sum2);
		my $dd_with_min_D = $deltas[0]; # запишем индекс дельта-функции с min числом D

		# перебрасываем по частям производную с этого сомножителя на другие => появляются другие слагаемые справа (!), о них не заботимся в этой итерации цикла, они будут обработаны в следующем вызове всей нашей подпрограммы workout_summand_deltas
		say "was_deleted" unless byparts_ext_der(0, $dd_with_min_D, \@sum2);

		# далее производим упрощение выражений с дельта-функцией у всего слагамого: в цикле для каждого сомножителя, на котором есть дельты
		foreach my $multiplicand (@deltas) {
			say "was_deleted" if (derivatives_commute(0, $multiplicand, \@sum2) eq "was_deleted"); # был удален при коммутировании производной (из-за D^3)
		}

		# теперь проверяем на наличие "голой" дельта-функции, и, если найдем, интегрируем ее
#		say "was_deleted" if (two_delta_one_naked(0, \@sum2) eq "was_deleted"); # выходим из цикла, если слагаемое было удалено (из-за dd DDD dd, наверное)
print_sum (@sum2);

__END__
say "Запускаем ЦИКЛ WORKOUT-ов дельта-функций: ";
for (my $counter = 0; $counter < @sum2; $counter++){
	$counter-- if (workout_summand_deltas ($counter, \@sum2) eq "was_deleted");
}

say "Запускаем ЦИКЛ WORKOUT-ов полей:";
for (my $counter = 0; $counter < @sum2; $counter++){
	$counter-- if (workout_summand_fields($counter, \@sum2) eq "was_deleted");
}
print_sum (@sum2);

say "Свернем все индексы (эпсилоны с верхними и нижними, а также кронекеры):";
for (my $counter = 0; $counter < @sum2; $counter++){
	epsilon_convolution($counter, \@sum2);
}
for (my $counter = 0; $counter < @sum2; $counter++){
	kronecker_convolution($counter, \@sum2);
}
print_sum (@sum2);


__END__
say "Что было изначально:";
print_sum (@sum);

say "Выравниваем индекс у 0-ого слагаемого 1-ого, 2-ого и 3-его сомножителей (дельта-функций)";
$sum[0]->coef($sum[0]->with_points->element(1)->index_align);
$sum[0]->coef($sum[0]->with_points->element(2)->index_align);
$sum[0]->coef($sum[0]->with_points->element(3)->index_align);
print_sum (@sum);

say "Опускаем индексы у 0-ого слагаемого";
$sum[0]->lower_index;
print_sum (@sum);

#say "Коммутируем прозводные с чертой вправо у 0-ого слагаемого, 2-ой сомножитель";
#derivatives_commute (0,2, \@sum);
#print_sum (@sum);


say "Запускаем ЦИКЛ WORKOUT-ов дельта-функций: ";
for (my $counter = 0; $counter < @sum; $counter++){
	$counter-- if (workout_summand_deltas ($counter, \@sum) eq "was_deleted");
}
print_sum (@sum);

#say "Прокоммутируем прозводные на полях у 0-ого слагаемого: ";
#derivatives_commute_fields (0, 0, \@sum);
#print_sum (@sum);


say "Запускаем ЦИКЛ WORKOUT-ов полей:";
for (my $counter = 0; $counter < @sum; $counter++){
	$counter-- if (workout_summand_fields($counter, \@sum) eq "was_deleted");
}
print_sum (@sum);

