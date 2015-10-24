
							#############################
							### MODULE BEST PRACTICES ###
							#############################


# WORKOUT_SUMMAND_DELTAS отдельно-взятого слагаемого
say "Пробуем обработать 0-ое слагаемое полностью. Для этого склонируем это слагаемое в новый массив слагаемых и отработаем его ЦИКЛОМ!";
my @sum_temp;
$sum_temp[0] = $sum[0]->clone;

for (my $counter = 0; $counter < @sum_temp; $counter++){
	$counter-- if (workout_summand_deltas ($counter, \@sum_temp) eq "was_deleted");
}
print_sum (@sum_temp);





# Выравниваение тета-индекса (точки) -- обратите внимание на то, как учитывается коэффициент с помощью специального рода сеттера для coef
say "Выравниваем индекс у 0-ого слагаемого 1-ого и 2-ого сомножителей (дельта-функций)";
$sum[0]->coef($sum[0]->with_points->element(1)->index_align);
$sum[0]->coef($sum[0]->with_points->element(2)->index_align);
print_sum (@sum);






# Простое перебрасывание производной по частям
say "Перебросим по частям внешнюю производную у 0-ого слагаемого, 1-ого сомножителя";
byparts_ext_der (0, 1, \@sum);
print_sum (@sum);

say "Перебросим по частям внешнюю производную у 6-ого слагаемого, 3-ого сомножителя";
(byparts_ext_der (6, 3, \@sum) eq 'nothing_to_do') ? say "БЕЗПОЛЕЗНО" : print_sum (@sum);