// Ported from spring-data-commons 4.2.0: src/test/java/org/springframework/data/domain/{SortUnitTests,PageImplUnitTests,PageRequestUnitTests,AbstractPageRequestUnitTests,DirectionUnitTests}.java
// Copyright 2008-present the original author or authors.
// Licensed under the Apache License, Version 2.0.
// Modified by the Flint authors: the `TypedPropertyPath`, `TypedSort` and `ScrollPosition` cases wait on those
// types; `preventsNullDirection` and `preventsNullProperties` have no D counterpart (a struct and a D array).
module flint.data.domain_test;

import flint.data.domain;
import flint.java.lang : IllegalArgumentException;
import flint.java.util : Arrays, Collections, List, Objects;
import std.exception : assertThrown;

@safe:

private alias Order = Sort.Order;
private alias Direction = Sort.Direction;
private alias NullHandling = Sort.NullHandling;

private Order[] ordersOf(Sort sort)
{
    Order[] result;
    foreach (order; sort)
        result ~= order;
    return result;
}

private bool same(A, B)(A left, B right)
{
    return Objects.equals(cast(Object) left, cast(Object) right);
}

private void assertEqualsAndHashcode(A, B)(A first, B second)
{
    assert(first.equals(cast(Object) second) && second.equals(cast(Object) first));
    assert(first.hashCode() == second.hashCode());
}

private void assertNotEqualsAndHashcode(A, B)(A first, B second)
{
    assert(!first.equals(cast(Object) second) && !second.equals(cast(Object) first));
    assert(first.hashCode() != second.hashCode());
}

// SortUnitTests

@("Sort: appliesDefaultForOrder")
unittest
{
    assert(Sort.by("foo").iterator().next().getDirection() == Sort.DEFAULT_DIRECTION);
}

@("Sort: preventsNullProperty, preventsEmptyProperty, preventsNoProperties")
unittest
{
    assertThrown!IllegalArgumentException(Sort.by(Direction.ASC, cast(string) null));
    assertThrown!IllegalArgumentException(Sort.by(Direction.ASC, ""));
    assertThrown!IllegalArgumentException(Sort.by(Direction.ASC, new string[0]));
}

@("Sort: allowsCombiningSorts, handlesAdditionalNullSort")
unittest
{
    auto sort = Sort.by("foo").and(Sort.by("bar"));
    assert(ordersOf(sort) == [Order.by("foo"), Order.by("bar")]);
    assert(ordersOf(Sort.by("foo").and(Sort.unsorted())) == [Order.by("foo")]);
}

@("Sort: configuresIgnoreCaseForOrder, orderDoesNotIgnoreCaseByDefault")
unittest
{
    assert(Order.asc("foo").ignoreCase().isIgnoreCase());
    assert(Sort.by(Order.by("foo").ignoreCase()).descending().iterator().next().isIgnoreCase());
    assert(Sort.by(Order.by("foo").ignoreCase()).ascending().iterator().next().isIgnoreCase());
    assert(!Order.by("foo").isIgnoreCase());
    assert(!Order.asc("foo").isIgnoreCase());
    assert(!Order.desc("foo").isIgnoreCase());
}

@("Sort: createsOrderWithDirection")
unittest
{
    assert(Order.asc("foo").getDirection() == Direction.ASC);
    assert(Order.desc("foo").getDirection() == Direction.DESC);
}

@("Sort: ordersWithDifferentIgnoreCaseDoNotEqual")
unittest
{
    auto foo = Order.by("foo");
    auto fooIgnoreCase = Order.by("foo").ignoreCase();
    assert(foo != fooIgnoreCase);
    assert(foo.hashCode() != fooIgnoreCase.hashCode());
}

@("Sort: null handling hints")
unittest
{
    assert(Order.by("foo").nullsFirst().getNullHandling() == NullHandling.NULLS_FIRST);
    assert(Order.by("foo").nullsLast().getNullHandling() == NullHandling.NULLS_LAST);
    assert(Order.by("foo").nullsNative().getNullHandling() == NullHandling.NATIVE);
    assert(Order.by("foo").getNullHandling() == NullHandling.NATIVE);
}

@("Sort: retainsNullHandlingAfterChangingDirection")
unittest
{
    auto order = Order.by("foo").with_(NullHandling.NULLS_FIRST);
    assert(Sort.by(order).ascending().iterator().next().getNullHandling() == NullHandling.NULLS_FIRST);
    assert(Sort.by(order).descending().iterator().next().getNullHandling() == NullHandling.NULLS_FIRST);
}

@("Sort: createsNewOrderForDifferentProperty")
unittest
{
    auto source = Order.desc("foo").nullsFirst().ignoreCase();
    auto result = source.withProperty("bar");
    assert(result.getProperty() == "bar");
    assert(result.getDirection() == source.getDirection());
    assert(result.getNullHandling() == source.getNullHandling());
    assert(result.isIgnoreCase() == source.isIgnoreCase());
}

@("Sort: createsNewOrderFromProperties")
unittest
{
    assert(Order.desc("foo").withProperties("firstName", "lastName") == Sort.by(Direction.DESC,
            "firstName", "lastName"));
}

@("Sort: reversesSortCorrectly")
unittest
{
    assert(ordersOf(Sort.by(Order.asc("center"), Order.desc("radius")).reverse()) == [
        Order.desc("center"), Order.asc("radius")
    ]);
}

@("Sort: toString")
unittest
{
    assert(Sort.unsorted().toString() == "UNSORTED");
    assert(Sort.by("id").toString() == "id: ASC");
    auto sort = Sort.by(Order.desc("name").nullsLast().ignoreCase(), Order.by("id"));
    assert(sort.toString() == "name: DESC, NULLS_LAST, ignoring case, id: ASC");
}

// DirectionUnitTests

@("Direction: jpaValueMapping, rejectsInvalidString")
unittest
{
    assert(Direction.fromString("asc") == Direction.ASC);
    assert(Direction.fromString("DESC") == Direction.DESC);
    assertThrown!IllegalArgumentException(Direction.fromString("foo"));
    assert(Direction.fromOptionalString("Desc").get() == Direction.DESC);
    assert(!Direction.fromOptionalString("").isPresent());
}

// AbstractPageRequestUnitTests and PageRequestUnitTests

@("PageRequest: preventsNegativePage, preventsNegativeSize, preventsPageSizeLessThanOne")
unittest
{
    assertThrown!IllegalArgumentException(PageRequest.of(-1, 10));
    assertThrown!IllegalArgumentException(PageRequest.of(0, -1));
    assertThrown!IllegalArgumentException(PageRequest.of(0, 0));
}

@("PageRequest: navigatesPageablesCorrectly")
unittest
{
    Pageable request = PageRequest.of(1, 10);
    assert(request.hasPrevious());
    assert(same(request.next(), PageRequest.of(2, 10)));
    auto first = request.previousOrFirst();
    assert(!first.hasPrevious());
    assert(same(first, PageRequest.of(0, 10)));
    assert(same(first, request.first()));
    assert(same(first.previousOrFirst(), first));
}

@("PageRequest: equalsHonoursPageAndSize")
unittest
{
    auto request = PageRequest.of(0, 10);
    assertEqualsAndHashcode(request, request);
    assertEqualsAndHashcode(request, PageRequest.of(0, 10));
    assertNotEqualsAndHashcode(request, PageRequest.of(1, 10));
    assertNotEqualsAndHashcode(request, PageRequest.of(0, 11));
}

@("PageRequest: getOffsetShouldNotCauseOverflow")
unittest
{
    assert(PageRequest.of(int.max, int.max).getOffset() > int.max);
}

@("PageRequest: equalsRegardsSortCorrectly")
unittest
{
    auto sort = Sort.by(Direction.DESC, "foo");
    AbstractPageRequest request = PageRequest.ofSize(10).withPage(1).withSort(sort);
    assertEqualsAndHashcode(request, request);
    assertEqualsAndHashcode(request, PageRequest.of(1, 10, sort));
    assertEqualsAndHashcode(request, PageRequest.ofSize(10).withPage(1).withSort(Direction.DESC, "foo"));
    assertEqualsAndHashcode(PageRequest.of(0, 10), PageRequest.of(0, 10));
    assertNotEqualsAndHashcode(request, PageRequest.of(1, 10));
    assertNotEqualsAndHashcode(request, PageRequest.of(1, 10, Direction.ASC, "foo"));
    assert(same(Pageable.unpaged(), Pageable.unpaged(Sort.unsorted())));
    assert(!same(Pageable.unpaged(), Pageable.unpaged(Sort.by("foo"))));
}

@("PageRequest: rejectsNullSort")
unittest
{
    assertThrown!IllegalArgumentException(PageRequest.of(0, 10, cast(Sort) null));
}

@("PageRequest: toString")
unittest
{
    assert(PageRequest.of(1, 10, Sort.by("id")).toString() == "Page request [number: 1, size 10, sort: id: ASC]");
}

// PageImplUnitTests

@("PageImpl: assertEqualsForSimpleSetup")
unittest
{
    auto page = new PageImpl!string(Collections.singletonList("Foo"));
    assertEqualsAndHashcode(page, page);
    assertEqualsAndHashcode(page, new PageImpl!string(Collections.singletonList("Foo")));
}

@("PageImpl: assertEqualsForComplexSetup")
unittest
{
    Pageable pageable = PageRequest.of(0, 10);
    auto content = Collections.singletonList("Foo");
    auto page = new PageImpl!string(content, pageable, 100);
    assertEqualsAndHashcode(page, page);
    assertEqualsAndHashcode(page, new PageImpl!string(content, pageable, 100));
    assertNotEqualsAndHashcode(page, new PageImpl!string(content, pageable, 90));
    assertNotEqualsAndHashcode(page, new PageImpl!string(content, PageRequest.of(1, 10), 100));
    assertNotEqualsAndHashcode(page, new PageImpl!string(content, PageRequest.of(0, 15), 100));
}

@("PageImpl: preventsNullContent")
unittest
{
    assertThrown!IllegalArgumentException(new PageImpl!string(null));
    assertThrown!IllegalArgumentException(new PageImpl!string(null, null, 0));
}

@("PageImpl: returnsNextPageable")
unittest
{
    Page!Object page = new PageImpl!Object(Collections.singletonList(new Object()), PageRequest.of(0, 1), 10);
    assert(page.isFirst());
    assert(!page.hasPrevious());
    assert(!page.previousPageable().isPaged());
    assert(!page.isLast());
    assert(page.hasNext());
    assert(same(page.nextPageable(), PageRequest.of(1, 1)));
}

@("PageImpl: returnsPreviousPageable")
unittest
{
    Page!Object page = new PageImpl!Object(Collections.singletonList(new Object()), PageRequest.of(1, 1), 2);
    assert(!page.isFirst());
    assert(page.hasPrevious());
    assert(same(page.previousPageable(), PageRequest.of(0, 1)));
    assert(page.isLast());
    assert(!page.hasNext());
    assert(!page.nextPageable().isPaged());
}

@("PageImpl: createsPageForEmptyContentCorrectly")
unittest
{
    List!string list = Collections.emptyList!string();
    Page!string page = new PageImpl!string(list);
    assert(page.getContent().equals(cast(Object) list));
    assert(page.getNumber() == 0);
    assert(page.getNumberOfElements() == 0);
    assert(page.getSize() == 0);
    assert(page.getSort() == Sort.unsorted());
    assert(page.getTotalElements() == 0);
    assert(page.getTotalPages() == 1);
    assert(!page.hasNext());
    assert(!page.hasPrevious());
    assert(page.isFirst());
    assert(page.isLast());
    assert(!page.hasContent());
}

@("PageImpl: returnsCorrectTotalPages")
unittest
{
    Page!string page = new PageImpl!string(Collections.singletonList("a"));
    assert(page.getTotalPages() == 1);
    assert(!page.hasNext());
    assert(!page.hasPrevious());
}

@("PageImpl: transformsPageCorrectly")
unittest
{
    Page!string page = new PageImpl!string(Arrays.asList("foo", "bar"), PageRequest.of(0, 2), 10);
    auto transformed = page.map((string s) => cast(int) s.length);
    assert(transformed.getContent().size() == 2);
    assert(transformed.getContent().get(0) == 3 && transformed.getContent().get(1) == 3);
}

@("PageImpl: adapts the total on the last page (DATACMNS-713)")
unittest
{
    assert(new PageImpl!string(Arrays.asList("foo", "bar"), PageRequest.of(0, 5), 3).getTotalElements() == 2);
    assert(new PageImpl!string(Arrays.asList("foo", "bar"), PageRequest.of(0, 5), 1).getTotalElements() == 2);
    assert(new PageImpl!string(Arrays.asList("foo", "bar"), PageRequest.of(1, 10), 13).getTotalElements() == 12);
    assert(new PageImpl!string(Arrays.asList("foo", "bar"), PageRequest.of(1, 10), 11).getTotalElements() == 12);
    assert(new PageImpl!string(Collections.emptyList!string(), PageRequest.of(1, 10), 0).getTotalElements() == 0);
}

@("PageImpl: returnsSelfPagablesIfThePageIsAlreadyTheFirstOrLastOne")
unittest
{
    Pageable pageable = PageRequest.of(0, 2);
    Slice!string page = new PageImpl!string(Arrays.asList("foo", "bar"), pageable, 2);
    assert(same(page.previousPageable(), Pageable.unpaged()));
    assert(same(page.previousOrFirstPageable(), pageable));
    assert(same(page.nextPageable(), Pageable.unpaged()));
    assert(same(page.nextOrLastPageable(), pageable));
}

@("PageImpl: usesContentLengthForSizeIfNoPageableGiven")
unittest
{
    Page!int page = new PageImpl!int(Arrays.asList(1, 2));
    assert(page.getSize() == 2);
    assert(page.getTotalPages() == 1);
    assert(!page.hasPrevious());
    assert(!page.hasNext());
}

@("PageImpl: toStringShouldNotInspectNullInstances")
unittest
{
    auto page = new PageImpl!Object(Collections.singletonList!Object(null));
    assert(page.toString() == "Page 1 of 1 containing UNKNOWN instances");
}
