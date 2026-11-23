// Ported from spring-data-commons 4.2.0: src/main/java/org/springframework/data/domain/{Sort,Pageable,Unpaged,AbstractPageRequest,PageRequest,Slice,Page,Chunk,PageImpl}.java
// Copyright 2008-present the original author or authors.
// Licensed under the Apache License, Version 2.0.
// Modified by the Flint authors.

/++
`org.springframework.data.domain`: sorting and pagination (ADR-030), the part that JDBC repositories and Spring MVC
paging use.

Adaptations:
$(UL
    $(LI `Sort.Direction` has methods, so it is a struct with `ASC` and `DESC` constants rather than a D `enum`.)
    $(LI `Slice` and `Pageable` mix abstract and default methods; the defaults are in `mixin Slice.Defaults` and
        `mixin Pageable.Defaults` (R3).)
    $(LI `Streamable` is `Iterable` here (R10); `map` takes a delegate (R9). `Sort` has `Iterable`'s methods but does
        not declare the interface: `Iterable!(Sort.Order)` inside `Sort`'s own base list is a recursive template
        expansion in D.)
    $(LI Not ported yet: the `TypedPropertyPath` overloads and `TypedSort` (property paths), `Pageable.toLimit` and
        `toScrollPosition` (`Limit`, `ScrollPosition`), and `SliceImpl`.)
)
+/
module flint.data.domain;

import flint.java.lang : IllegalArgumentException, Iterable;
import flint.java.util : ArrayList, Collections, Iterator, List, Objects, Optional;

@safe:

/// Sort option for queries: a list of `Order`s, one per property.
class Sort
{
    /// The default direction, ascending.
    enum Direction DEFAULT_DIRECTION = Direction.ASC;

    private List!Order orders;

    /// A sort over `orders`.
    protected this(List!Order orders)
    {
        this.orders = orders;
    }

    private this(Direction direction, string[] properties)
    {
        if (properties.length == 0)
            throw new IllegalArgumentException("You have to provide at least one property to sort by");
        auto result = new ArrayList!Order();
        foreach (property; properties)
            result.add(new Order(direction, property));
        this.orders = result;
    }

    /// A sort for the given properties, ascending; unsorted when none are given.
    static Sort by(string[] properties...)
    {
        return properties.length == 0 ? Sort.unsorted() : new Sort(DEFAULT_DIRECTION, properties.dup);
    }

    /// A sort for the given orders; unsorted when the list is empty.
    static Sort by(List!Order orders)
    {
        if (orders is null)
            throw new IllegalArgumentException("Orders must not be null");
        return orders.isEmpty() ? Sort.unsorted() : new Sort(orders);
    }

    /// A sort for the given orders.
    static Sort by(Order[] orders...)
    {
        return new Sort(List!Order.of(orders));
    }

    /// A sort for the given properties, all in `direction`.
    static Sort by(Direction direction, string[] properties...)
    {
        if (properties.length == 0)
            throw new IllegalArgumentException("At least one property must be given");
        auto result = new ArrayList!Order();
        foreach (property; properties)
            result.add(new Order(direction, property));
        return Sort.by(cast(List!Order) result);
    }

    /// A sort instance representing no sorting at all.
    static Sort unsorted()
    {
        return new Sort(Collections.emptyList!Order());
    }

    /// A new sort with the current orders, descending.
    Sort descending()
    {
        return withDirection(Direction.DESC);
    }

    /// A new sort with the current orders, ascending.
    Sort ascending()
    {
        return withDirection(Direction.ASC);
    }

    ///
    bool isSorted()
    {
        return !isEmpty();
    }

    ///
    bool isEmpty()
    {
        return orders.isEmpty();
    }

    ///
    bool isUnsorted()
    {
        return !isSorted();
    }

    /// A new sort of these orders followed by those of `sort`.
    Sort and(Sort sort)
    {
        if (sort is null)
            throw new IllegalArgumentException("Sort must not be null");
        auto these = new ArrayList!Order();
        foreach (order; this)
            these.add(order);
        foreach (order; sort)
            these.add(order);
        return Sort.by(cast(List!Order) these);
    }

    /// A new sort with every order's direction reversed.
    Sort reverse()
    {
        return Sort.by(doReverse());
    }

    /// The reversed orders.
    protected List!Order doReverse()
    {
        auto reversed = new ArrayList!Order();
        foreach (order; this)
            reversed.add(order.reverse());
        return reversed;
    }

    /// The order registered for `property`, or null.
    Order getOrderFor(string property)
    {
        foreach (order; this)
            if (order.getProperty() == property)
                return order;
        return null;
    }

    /// The orders, as a list.
    List!Order toList()
    {
        auto result = new ArrayList!Order();
        foreach (order; this)
            result.add(order);
        return result;
    }

    /// An iterator over the orders.
    Iterator!Order iterator()
    {
        return orders.iterator();
    }

    /// Call `action` for each order.
    void forEach(void delegate(Order) @safe action)
    {
        foreach (order; this)
            action(order);
    }

    /// `foreach (order; sort)`.
    int opApply(scope int delegate(Order) @safe dg)
    {
        for (auto it = iterator(); it.hasNext();)
            if (auto result = dg(it.next()))
                return result;
        return 0;
    }

    /// Java's `equals`: the same orders.
    bool equals(Object obj)
    {
        if (this is obj)
            return true;
        auto that = cast(Sort) obj;
        return that !is null && toList().equals(cast(Object) that.toList());
    }

    /// Java's `hashCode`.
    int hashCode()
    {
        return orders.hashCode();
    }

    override string toString()
    {
        if (isEmpty())
            return "UNSORTED";
        string result;
        foreach (order; this)
            result ~= (result.length ? ", " : "") ~ order.toString();
        return result;
    }

    import flint.java.lang : JavaObject;

    mixin JavaObject;

    private Sort withDirection(Direction direction)
    {
        auto result = new ArrayList!Order();
        foreach (order; this)
            result.add(order.with_(direction));
        return Sort.by(cast(List!Order) result);
    }

    /// Enumeration for sort directions: `Sort.Direction.ASC` and `Sort.Direction.DESC`.
    static struct Direction
    {
        private int ordinal_;

        /// Ascending.
        enum Direction ASC = Direction(0);
        /// Descending.
        enum Direction DESC = Direction(1);

        /// Whether the direction is ascending.
        bool isAscending() const pure nothrow @nogc
        {
            return this == ASC;
        }

        /// Whether the direction is descending.
        bool isDescending() const pure nothrow @nogc
        {
            return this == DESC;
        }

        /// Java's `name()`.
        string name() const pure nothrow @nogc
        {
            return ordinal_ == 0 ? "ASC" : "DESC";
        }

        /// Java's `ordinal()`.
        int ordinal() const pure nothrow @nogc
        {
            return ordinal_;
        }

        /// The constant's name, as for a Java enum.
        string toString() const pure nothrow @nogc
        {
            return name();
        }

        /// The direction for `value`, "asc" or "desc" in any case. Throws `IllegalArgumentException` otherwise.
        static Direction fromString(string value)
        {
            Direction result;
            if (!tryParse(value, result))
                throw new IllegalArgumentException(
                        "Invalid value '" ~ value
                        ~ "' for orders given; Has to be either 'desc' or 'asc' (case insensitive)");
            return result;
        }

        /// The direction for `value`, or empty when it is empty or not a direction.
        static Optional!Direction fromOptionalString(string value)
        {
            Direction result;
            return value.length != 0 && tryParse(value, result)
                ? Optional!Direction.of(result) : Optional!Direction.empty();
        }

        private static bool tryParse(string value, ref Direction result) pure nothrow @nogc
        {
            if (equalsAsciiIgnoreCase(value, "asc"))
                result = ASC;
            else if (equalsAsciiIgnoreCase(value, "desc"))
                result = DESC;
            else
                return false;
            return true;
        }
    }

    /// Enumeration for null handling hints in query execution.
    enum NullHandling
    {
        /// Lets the data store decide.
        NATIVE,
        /// Nulls before non-null values.
        NULLS_FIRST,
        /// Nulls after non-null values.
        NULLS_LAST,
    }

    /// A property and its direction: one `Sort` criterion.
    static class Order
    {
        private const Direction direction;
        private const string property;
        private const bool ignoreCase_;
        private const NullHandling nullHandling;

        /// An order for `property` in `direction`.
        this(Direction direction, string property)
        {
            this(direction, property, false, NullHandling.NATIVE);
        }

        /// An order for `property` in `direction`, with a null handling hint.
        this(Direction direction, string property, NullHandling nullHandlingHint)
        {
            this(direction, property, false, nullHandlingHint);
        }

        /// An order for `property` in `direction`, ignoring case or not, with a null handling hint.
        this(Direction direction, string property, bool ignoreCase, NullHandling nullHandling)
        {
            if (!hasText(property))
                throw new IllegalArgumentException("Property must not be null or empty");
            this.direction = direction;
            this.property = property;
            this.ignoreCase_ = ignoreCase;
            this.nullHandling = nullHandling;
        }

        /// An ascending order for `property`.
        static Order by(string property)
        {
            return new Order(DEFAULT_DIRECTION, property);
        }

        /// An ascending order for `property`.
        static Order asc(string property)
        {
            return new Order(Direction.ASC, property, NullHandling.NATIVE);
        }

        /// A descending order for `property`.
        static Order desc(string property)
        {
            return new Order(Direction.DESC, property, NullHandling.NATIVE);
        }

        ///
        Direction getDirection()
        {
            return direction;
        }

        ///
        string getProperty()
        {
            return property;
        }

        ///
        bool isAscending()
        {
            return direction.isAscending();
        }

        ///
        bool isDescending()
        {
            return direction.isDescending();
        }

        ///
        bool isIgnoreCase()
        {
            return ignoreCase_;
        }

        /// Java's `with(Direction)`: `with` is a D keyword.
        Order with_(Direction direction)
        {
            return new Order(direction, property, ignoreCase_, nullHandling);
        }

        /// The same order, reversed.
        Order reverse()
        {
            return with_(direction == Direction.ASC ? Direction.DESC : Direction.ASC);
        }

        /// The same order for another property.
        Order withProperty(string property)
        {
            return new Order(direction, property, ignoreCase_, nullHandling);
        }

        /// A sort of these properties in this order's direction.
        Sort withProperties(string[] properties...)
        {
            return Sort.by(direction, properties);
        }

        /// The same order, ignoring case.
        Order ignoreCase()
        {
            return new Order(direction, property, true, nullHandling);
        }

        /// Java's `with(NullHandling)`.
        Order with_(NullHandling nullHandling)
        {
            return new Order(direction, property, ignoreCase_, nullHandling);
        }

        ///
        Order nullsFirst()
        {
            return with_(NullHandling.NULLS_FIRST);
        }

        ///
        Order nullsLast()
        {
            return with_(NullHandling.NULLS_LAST);
        }

        ///
        Order nullsNative()
        {
            return with_(NullHandling.NATIVE);
        }

        ///
        NullHandling getNullHandling()
        {
            return nullHandling;
        }

        /// Java's `equals`.
        bool equals(Object obj)
        {
            if (this is obj)
                return true;
            auto that = cast(Order) obj;
            return that !is null && direction == that.direction && property == that.property
                && ignoreCase_ == that.ignoreCase_ && nullHandling == that.nullHandling;
        }

        /// Java's `hashCode`.
        int hashCode()
        {
            return Objects.hash(direction.ordinal(), property, ignoreCase_, cast(int) nullHandling);
        }

        override string toString()
        {
            string result = property ~ ": " ~ direction.name();
            if (nullHandling != NullHandling.NATIVE)
                result ~= ", " ~ (nullHandling == NullHandling.NULLS_FIRST ? "NULLS_FIRST" : "NULLS_LAST");
            if (ignoreCase_)
                result ~= ", ignoring case";
            return result;
        }

        import flint.java.lang : JavaObject;

        mixin JavaObject;
    }
}

/// Abstract interface for pagination information.
interface Pageable
{
    /// A `Pageable` for no pagination.
    static Pageable unpaged()
    {
        return unpaged(Sort.unsorted());
    }

    /// A `Pageable` for no pagination, sorted by `sort`.
    static Pageable unpaged(Sort sort)
    {
        return Unpaged.sorted(sort);
    }

    /// The first page of `pageSize` elements.
    static Pageable ofSize(int pageSize)
    {
        return PageRequest.of(0, pageSize);
    }

    /// Whether this pages; `false` for `unpaged()`.
    bool isPaged();
    /// Whether this does not page.
    bool isUnpaged();
    /// The page to be returned. Throws `UnsupportedOperationException` when unpaged.
    int getPageNumber();
    /// The number of items to be returned. Throws `UnsupportedOperationException` when unpaged.
    int getPageSize();
    /// The offset to be taken according to the page and page size.
    long getOffset();
    /// The sorting parameters.
    Sort getSort();
    /// The current sort, or `sort` when unsorted.
    Sort getSortOr(Sort sort);
    /// The page after this one.
    Pageable next();
    /// The previous page, or the first when this is the first.
    Pageable previousOrFirst();
    /// The first page.
    Pageable first();
    /// This page size, at `pageNumber`.
    Pageable withPage(int pageNumber);
    /// Whether there is a page before this one.
    bool hasPrevious();
    /// This, or empty when unpaged.
    Optional!Pageable toOptional();

    /// Java's default methods (R3).
    mixin template Defaults()
    {
        bool isPaged()
        {
            return true;
        }

        bool isUnpaged()
        {
            return !isPaged();
        }

        Sort getSortOr(Sort sort)
        {
            if (sort is null)
                throw new IllegalArgumentException("Fallback Sort must not be null");
            return getSort().isSorted() ? getSort() : sort;
        }

        Optional!Pageable toOptional()
        {
            return isUnpaged() ? Optional!Pageable.empty() : Optional!Pageable.of(this);
        }
    }
}

/// `Pageable.unpaged()`: no pagination, optionally sorted.
final class Unpaged : Pageable
{
    private Sort sort;

    private this(Sort sort)
    {
        this.sort = sort;
    }

    /// An unpaged instance sorted by `sort`.
    static Pageable sorted(Sort sort)
    {
        return new Unpaged(sort);
    }

    mixin Pageable.Defaults;

    override bool isPaged()
    {
        return false;
    }

    override Pageable previousOrFirst()
    {
        return this;
    }

    override Pageable next()
    {
        return this;
    }

    override bool hasPrevious()
    {
        return false;
    }

    override Sort getSort()
    {
        return sort;
    }

    override int getPageSize()
    {
        import flint.java.lang : UnsupportedOperationException;

        throw new UnsupportedOperationException();
    }

    override int getPageNumber()
    {
        import flint.java.lang : UnsupportedOperationException;

        throw new UnsupportedOperationException();
    }

    override long getOffset()
    {
        import flint.java.lang : UnsupportedOperationException;

        throw new UnsupportedOperationException();
    }

    override Pageable first()
    {
        return this;
    }

    override Pageable withPage(int pageNumber)
    {
        if (pageNumber == 0)
            return this;
        import flint.java.lang : UnsupportedOperationException;

        throw new UnsupportedOperationException();
    }

    /// Java's `equals`.
    bool equals(Object obj)
    {
        auto that = cast(Unpaged) obj;
        return that !is null && sort.equals(that.sort);
    }

    /// Java's `hashCode`.
    int hashCode()
    {
        return sort.hashCode();
    }

    override string toString()
    {
        return "Unpaged";
    }

    import flint.java.lang : JavaObject;

    mixin JavaObject;
}

/// Abstract Java Bean implementation of `Pageable`.
abstract class AbstractPageRequest : Pageable
{
    private const int pageNumber;
    private const int pageSize;

    /// A page request for `pageNumber` (zero-based) of `pageSize` elements.
    this(int pageNumber, int pageSize)
    {
        if (pageNumber < 0)
            throw new IllegalArgumentException("Page index must not be less than zero");
        if (pageSize < 1)
            throw new IllegalArgumentException("Page size must not be less than one");
        this.pageNumber = pageNumber;
        this.pageSize = pageSize;
    }

    mixin Pageable.Defaults;

    override int getPageSize()
    {
        return pageSize;
    }

    override int getPageNumber()
    {
        return pageNumber;
    }

    override long getOffset()
    {
        return cast(long) pageNumber * cast(long) pageSize;
    }

    override bool hasPrevious()
    {
        return pageNumber > 0;
    }

    override Pageable previousOrFirst()
    {
        return hasPrevious() ? previous() : first();
    }

    abstract override Pageable next();

    /// The page before this one.
    abstract Pageable previous();

    abstract override Pageable first();

    /// Java's `equals`.
    bool equals(Object o)
    {
        if (this is o)
            return true;
        auto that = cast(AbstractPageRequest) o;
        return that !is null && pageNumber == that.pageNumber && pageSize == that.pageSize;
    }

    /// Java's `hashCode`.
    int hashCode()
    {
        return Objects.hash(pageNumber, pageSize);
    }
}

/// Basic Java Bean implementation of `Pageable`.
class PageRequest : AbstractPageRequest
{
    private Sort sort;

    /// A page request for `pageNumber` (zero-based) of `pageSize` elements, sorted by `sort`.
    protected this(int pageNumber, int pageSize, Sort sort)
    {
        super(pageNumber, pageSize);
        if (sort is null)
            throw new IllegalArgumentException("Sort must not be null");
        this.sort = sort;
    }

    /// An unsorted page request.
    static PageRequest of(int pageNumber, int pageSize)
    {
        return of(pageNumber, pageSize, Sort.unsorted());
    }

    /// A sorted page request.
    static PageRequest of(int pageNumber, int pageSize, Sort sort)
    {
        return new PageRequest(pageNumber, pageSize, sort);
    }

    /// A page request sorted by `properties` in `direction`.
    static PageRequest of(int pageNumber, int pageSize, Sort.Direction direction, string[] properties...)
    {
        return of(pageNumber, pageSize, Sort.by(direction, properties));
    }

    /// The first page of `pageSize` elements, unsorted.
    static PageRequest ofSize(int pageSize)
    {
        return PageRequest.of(0, pageSize);
    }

    override Sort getSort()
    {
        return sort;
    }

    override PageRequest next()
    {
        return new PageRequest(getPageNumber() + 1, getPageSize(), getSort());
    }

    override PageRequest previous()
    {
        return getPageNumber() == 0 ? this : new PageRequest(getPageNumber() - 1, getPageSize(), getSort());
    }

    override PageRequest first()
    {
        return new PageRequest(0, getPageSize(), getSort());
    }

    override PageRequest withPage(int pageNumber)
    {
        return new PageRequest(pageNumber, getPageSize(), getSort());
    }

    /// This page, sorted by `properties` in `direction`.
    PageRequest withSort(Sort.Direction direction, string[] properties...)
    {
        return new PageRequest(getPageNumber(), getPageSize(), Sort.by(direction, properties));
    }

    /// This page, sorted by `sort`.
    PageRequest withSort(Sort sort)
    {
        return new PageRequest(getPageNumber(), getPageSize(), sort);
    }

    /// Java's `equals`.
    override bool equals(Object o)
    {
        if (this is o)
            return true;
        auto that = cast(PageRequest) o;
        return that !is null && super.equals(o) && sort.equals(that.sort);
    }

    /// Java's `hashCode`.
    override int hashCode()
    {
        return super.hashCode() * 31 + sort.hashCode();
    }

    override string toString()
    {
        import flint.engine.aot.text : decimal;

        return "Page request [number: " ~ decimal(long(getPageNumber())) ~ ", size " ~ decimal(
                long(getPageSize())) ~ ", sort: " ~ sort.toString() ~ "]";
    }

    import flint.java.lang : JavaObject;

    mixin JavaObject;
}

/// A slice of data that indicates whether there's a next or previous slice available.
interface Slice(T) : Iterable!T
{
    /// The number of the current slice, zero-based.
    int getNumber();
    /// The size of the slice.
    int getSize();
    /// The number of elements currently on this slice.
    int getNumberOfElements();
    /// The slice content as a list.
    List!T getContent();
    /// Whether the slice has content at all.
    bool hasContent();
    /// The sorting parameters.
    Sort getSort();
    /// Whether this is the first slice.
    bool isFirst();
    /// Whether this is the last slice.
    bool isLast();
    /// Whether there is a next slice.
    bool hasNext();
    /// Whether there is a previous slice.
    bool hasPrevious();
    /// The `Pageable` that requested this slice.
    Pageable getPageable();
    /// The `Pageable` for the next slice, or unpaged.
    Pageable nextPageable();
    /// The `Pageable` for the previous slice, or unpaged.
    Pageable previousPageable();
    /// The next slice's `Pageable`, or this one's when this is the last.
    Pageable nextOrLastPageable();
    /// The previous slice's `Pageable`, or this one's when this is the first.
    Pageable previousOrFirstPageable();

    /// Java's default methods (R3).
    mixin template Defaults()
    {
        Pageable getPageable()
        {
            return PageRequest.of(getNumber(), getSize(), getSort());
        }

        Pageable nextOrLastPageable()
        {
            return hasNext() ? nextPageable() : getPageable();
        }

        Pageable previousOrFirstPageable()
        {
            return hasPrevious() ? previousPageable() : getPageable();
        }
    }
}

/// A sublist of a list of objects, with information about its position in the entire list.
interface Page(T) : Slice!T
{
    /// An empty, unpaged page.
    static Page!T empty()
    {
        return empty(Pageable.unpaged());
    }

    /// An empty page for `pageable`.
    static Page!T empty(Pageable pageable)
    {
        return new PageImpl!T(Collections.emptyList!T(), pageable, 0);
    }

    /// The number of total pages.
    int getTotalPages();
    /// The total amount of elements.
    long getTotalElements();

    /// A page of the content mapped by `converter` (R9).
    Page!U map(U)(U delegate(T) @safe converter)
    {
        auto content = new ArrayList!U();
        foreach (element; this)
            content.add(converter(element));
        return new PageImpl!U(content, getPageable(), getTotalElements());
    }
}

/// A chunk of data restricted by the configured `Pageable`.
abstract class Chunk(T) : Slice!T
{
    private List!T content;
    private Pageable pageable;

    /// A chunk of `content` for `pageable`.
    this(List!T content, Pageable pageable)
    {
        if (content is null)
            throw new IllegalArgumentException("Content must not be null");
        if (pageable is null)
            throw new IllegalArgumentException("Pageable must not be null");
        auto copy = new ArrayList!T();
        foreach (element; content)
            copy.add(element);
        this.content = copy;
        this.pageable = pageable;
    }

    mixin Slice!T.Defaults _defaults;
    alias nextOrLastPageable = _defaults.nextOrLastPageable;
    alias previousOrFirstPageable = _defaults.previousOrFirstPageable;

    override int getNumber()
    {
        return pageable.isPaged() ? pageable.getPageNumber() : 0;
    }

    override int getSize()
    {
        return pageable.isPaged() ? pageable.getPageSize() : content.size();
    }

    override int getNumberOfElements()
    {
        return content.size();
    }

    override bool hasPrevious()
    {
        return getNumber() > 0;
    }

    override bool isFirst()
    {
        return !hasPrevious();
    }

    override bool isLast()
    {
        return !hasNext();
    }

    override Pageable nextPageable()
    {
        return hasNext() ? pageable.next() : Pageable.unpaged();
    }

    override Pageable previousPageable()
    {
        return hasPrevious() ? pageable.previousOrFirst() : Pageable.unpaged();
    }

    override bool hasContent()
    {
        return !content.isEmpty();
    }

    override List!T getContent()
    {
        return Collections.unmodifiableList(content);
    }

    override Pageable getPageable()
    {
        return pageable;
    }

    override Sort getSort()
    {
        return pageable.getSort();
    }

    override Iterator!T iterator()
    {
        return content.iterator();
    }

    override void forEach(void delegate(T) @safe action)
    {
        content.forEach(action);
    }

    override int opApply(scope int delegate(T) @safe dg)
    {
        return content.opApply(dg);
    }

    /// Java's `equals`.
    bool equals(Object o)
    {
        if (this is o)
            return true;
        auto that = cast(Chunk!T) o;
        return that !is null && content.equals(cast(Object) that.content) && Objects.equals(pageable, that.pageable);
    }

    /// Java's `hashCode`.
    int hashCode()
    {
        return Objects.hash(content, pageable);
    }
}

/// Basic `Page` implementation.
class PageImpl(T) : Chunk!T, Page!T
{
    private const long total;

    /// A page of `content` for `pageable`, out of `total` elements in all.
    this(List!T content, Pageable pageable, long total)
    {
        super(content, pageable);
        // Java: pageable.toOptional().filter(!content.isEmpty()).filter(offset + size > total)
        //   .map(offset + content.size()).orElse(total)
        if (pageable.isPaged() && !content.isEmpty() && pageable.getOffset() + pageable.getPageSize() > total)
            this.total = pageable.getOffset() + content.size();
        else
            this.total = total;
    }

    /// A single, unpaged page of all of `content`.
    this(List!T content)
    {
        this(content, Pageable.unpaged(), content is null || content.isEmpty() ? 0 : content.size());
    }

    override int getTotalPages()
    {
        import std.math : ceil;

        return getSize() == 0 ? 1 : cast(int) ceil(cast(double) total / cast(double) getSize());
    }

    override long getTotalElements()
    {
        return total;
    }

    override bool hasNext()
    {
        return getNumber() + 1 < getTotalPages();
    }

    override bool isLast()
    {
        return !hasNext();
    }

    /// Java's `equals`.
    override bool equals(Object obj)
    {
        if (this is obj)
            return true;
        auto that = cast(PageImpl!T) obj;
        return that !is null && total == that.total && super.equals(obj);
    }

    /// Java's `hashCode`.
    override int hashCode()
    {
        return 31 * super.hashCode() + cast(int)(total ^ (total >>> 32));
    }

    override string toString()
    {
        import flint.engine.aot.text : decimal;
        import flint.engine.aot.name : typeNameOf;

        auto content = getContent();
        string contentType = "UNKNOWN";
        if (!content.isEmpty())
        {
            static if (is(T == class) || is(T == interface))
            {
                if (auto object = cast(Object) content.get(0))
                    contentType = typeid(object).name;
            }
            else
                contentType = typeNameOf!T;
        }
        return "Page " ~ decimal(long(getNumber() + 1)) ~ " of " ~ decimal(
                long(getTotalPages())) ~ " containing " ~ contentType ~ " instances";
    }

    import flint.java.lang : JavaObject;

    mixin JavaObject;
}

private bool hasText(string text) pure nothrow @nogc
{
    foreach (c; text)
        if (c != ' ' && c != '\t' && c != '\n' && c != '\r' && c != '\f' && c != '\v')
            return true;
    return false;
}

private bool equalsAsciiIgnoreCase(string a, string b) pure nothrow @nogc
{
    if (a.length != b.length)
        return false;
    foreach (i; 0 .. a.length)
    {
        char x = a[i], y = b[i];
        if (x >= 'A' && x <= 'Z')
            x += 'a' - 'A';
        if (y >= 'A' && y <= 'Z')
            y += 'a' - 'A';
        if (x != y)
            return false;
    }
    return true;
}
