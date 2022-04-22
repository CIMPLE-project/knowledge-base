URI patterns for CIMPLE data
==============================

This file documents how the URI are generated for the CIMPLE data.

## Main entities

Pattern:

```turtle
http://data.cimple.eu/<group>/<uuid>
# i.e. http://data.cimple.eu/news/803aee3d-eecb-35fc-831f-f9a1a8d3561f
```

The `<group>` is taken from this table:

| Class | group |
| --- | --- |
| http://schema.org/Event | event |
|  | category |
| http://schema.org/CreativeWork | cluster |
| http://iptc.org/std/rNews/2011-10-07#Article | news |

## Secondary entities

This group includes entities that cover specific information about the main entities.
The URI is realized appending a suffix to the parent main entity.

Pattern if only one instance per main entity is expected:

``` turtle
<uri of the main entity>/<suffix>
# i.e. http://data.cimple.eu/news/803aee3d-eecb-35fc-831f-f9a1a8d3561f/contentLocation
```

The `<suffix>` is taken from this table:

| Class | suffix |
| --- | --- |
| http://schema.org/Place | contentLocation |
| http://schema.org/PostalAddress | contentLocation/address |