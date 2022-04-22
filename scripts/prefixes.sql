DB.DBA.XML_REMOVE_NS_BY_PREFIX ('dc', 2);
DB.DBA.XML_REMOVE_NS_BY_PREFIX ('rdf', 2);
DB.DBA.XML_REMOVE_NS_BY_PREFIX ('rnews', 2);
DB.DBA.XML_REMOVE_NS_BY_PREFIX ('schema', 2);
DB.DBA.XML_REMOVE_NS_BY_PREFIX ('xsd', 2);

DB.DBA.XML_SET_NS_DECL ('dc', 'http://purl.org/dc/elements/1.1/', 2);
DB.DBA.XML_SET_NS_DECL ('rdf', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 2);
DB.DBA.XML_SET_NS_DECL ('rnews', 'http://iptc.org/std/rNews/2011-10-07#', 2);
DB.DBA.XML_SET_NS_DECL ('schema', 'http://schema.org/', 2);
DB.DBA.XML_SET_NS_DECL ('xsd', 'http://www.w3.org/2001/XMLSchema#', 2);
