/// spring-data-commons' PageRequest and PageImpl over a java.util list: the v2 paged listing of petclinic-rest.
module app;

import flint.data.domain : Page, PageImpl, PageRequest, Sort;
import flint.java.util : ArrayList;
import core.stdc.stdio : fputc, stdout;

@safe:

/// Writes one line without Phobos, so the probe adds no std.format template instances to the module's count.
private void emit(scope const(char)[] text) nothrow @nogc
{
    foreach (c; text)
        fputc(c, stdout);
    fputc('\n', stdout);
}

int main(string[] args)
{
    auto content = new ArrayList!string();
    content.add(args.length > 1 ? "Jean" : "George");
    Page!string page = new PageImpl!string(content, PageRequest.of(1, 1, Sort.by("id")), 3);
    emit(page.getContent().get(0) ~ " " ~ cast(char)('0' + page.getTotalPages()));
    return 0;
}
