from rdflib import Graph, Literal, URIRef, XSD
from rdflib.namespace import RDF, FOAF, SDO, Namespace
from tqdm import tqdm, trange
import hashlib
import re 
import requests
import json
import io

SO = Namespace("http://schema.org/")
WIKI_prefix = "http://www.wikidata.org/wiki/"
DB_prefix = "http://dbpedia.org/ontology/"

prefix = "http://claimreview-kb.tools.eurecom.fr/"

g = Graph()

directory = '../cr_data/'

print('Loading Claim Reviews old')
cr_old = json.load(io.open(directory+'old/claim_reviews.json'))
print('Loading Entities old')
d_entities = json.load(io.open(directory+'old/entities_dict.json'))
print('Loading Claim Reviews new')
cr_new = json.load(io.open(directory+'new/claim_reviews.json'))

def normalize_text(text):
    text = text.replace('&amp;', '&')
    text = text.replace('\xa0', '')
    text = re.sub(r'http\S+', '', text)
    text = " ".join(text.split())
    return text
def uri_generator(identifier):
    h = hashlib.sha224(str.encode(identifier)).hexdigest()
    
    return str(h)


d_new_entities = {}
text_to_extract = []
for i in range(0, len(cr_new)):
    raw_text = cr_new[i]['claim_text'][0]
    
    if raw_text in d_entities:
        raw_dbpedia_output = d_entities[raw_text]
        d_new_entities[raw_text] = raw_dbpedia_output
    else:
        if raw_text not in text_to_extract:
            text_to_extract.append(raw_text)
            
API_URL = "https://api.dbpedia-spotlight.org/en/annotate"

print('Extracting new entities from new texts')
new_entities = []
for s in tqdm(text_to_extract):
    s = normalize_text(s)
    
    if not s in ['', ' ', '   ']:
        payload = {'text': s}
        a = requests.post(API_URL, 
                     headers={'accept': 'application/json'},
                     data=payload).json()

        new_entities.append(a)
    else:
        new_entities.append([])
        
for i in range(0, len(text_to_extract)):
    d_new_entities[text_to_extract[i]] = new_entities[i]

print('Saving updated entities dict to ../cr_data/new/entities.json')
with open(directory+'../cr_data/new/entities_dict.json', 'w') as f:
    json.dump(d_new_entities, f)


all_organizations_names = []
all_organizations_websites = []

for cr in cr_new:
    author = cr['fact_checker']['name']
    website = cr['fact_checker']['website']
    if author not in all_organizations_names:
        all_organizations_names.append(author)
        all_organizations_websites.append(website)
        
        
errors = []

print('Creating Graph')
for i in trange(0, len(cr_new)):
    cr = cr_new[i]
    
    identifier = 'claim_reviews'+str(i)
    uri = 'claim_reviews/'+uri_generator(identifier)
    g.add((URIRef(prefix+uri), RDF.type, SO.ClaimReview))
    
    author = cr['fact_checker']['name']
    website = cr['fact_checker']['website']
    identifier_author = 'organization'+str(author)
    uri_author = 'organization/'+uri_generator(identifier_author)
    
    g.add((URIRef(prefix+uri_author), RDF.type, SO.Organization))
    g.add((URIRef(prefix+uri_author), SO.name, Literal(author)))
    g.add((URIRef(prefix+uri_author), SO.url, URIRef(website)))

    g.add((URIRef(prefix+uri), SO.author, URIRef(prefix+uri_author)))
    

    date = cr['reviews'][0]['date_published']

    g.add((URIRef(prefix+uri), SO.datePublished, Literal(date, datatype=XSD.date)))
    
    url = cr['review_url']
    url = url.replace(' ', '')
    g.add((URIRef(prefix+uri), SO.url, URIRef(url)))
    
    language = cr['fact_checker']['language']
    g.add((URIRef(prefix+uri), SO.inLanguage, Literal(language)))
    
    #identifier_rating = 'claim_reviews_rating'+str(i)
    #uri_rating = 'rating/'+uri_generator(identifier_rating)
    uri_rating = 'rating/'+cr['reviews'][0]['label']
    
    g.add((URIRef(prefix+uri), SO.reviewRating, URIRef(prefix+uri_rating)))

    
    claim = cr['claim_text'][0]
    identifier_claim = 'claims'+str(i)
    uri_claim = 'claims/'+uri_generator(identifier_claim)
    
    #SO.Claim has not yet been integrated
    #This term is proposed for full integration into Schema.org, pending implementation feedback and adoption from applications and websites. 
    g.add((URIRef(prefix+uri_claim),RDF.type, SO.Claim))
    
    g.add((URIRef(prefix+uri), SO.itemReviewed, URIRef(prefix+uri_claim)))

    text = claim
    text = normalize_text(text)

    g.add((URIRef(prefix+uri_claim),SO.text, Literal(text)))
    
    text = normalize_text(text)
    
    dbpedia_output = d_new_entities[claim]
    
    if 'Resources' in dbpedia_output:
        entities = dbpedia_output['Resources']
    
        for e in entities:
            dbpedia_url = e['@URI']
            dbpedia_name = e['@URI'][28:].replace('_', ' ')
            entity_types = e['@types'].split(',')

            identifier_mention = 'entity'+str(dbpedia_url)
            uri_mention = 'entity/'+uri_generator(identifier_mention)
            
            g.add((URIRef(prefix+uri_mention), RDF.type, SO.Thing))
            for t in entity_types:
                if "Wikidata" in t:
                    g.add((URIRef(prefix+uri_mention), RDF.type, URIRef(WIKI_prefix+t.split(':')[1])))
                if "DBpedia" in t:
                    g.add((URIRef(prefix+uri_mention), RDF.type, URIRef(DB_prefix+t.split(':')[1])))
                    
            g.add((URIRef(prefix+uri_mention), SO.url, URIRef(dbpedia_url)))
            g.add((URIRef(prefix+uri_mention), SO.name, Literal(dbpedia_name)))
            g.add((URIRef(prefix+uri_claim), SO.mentions, URIRef(prefix+uri_mention)))

print('Done')
labels_mapping = json.load(io.open(directory+'new/claim_labels_mapping.json'))

print('Adding normalized ratings to graph')
for label in tqdm(labels_mapping):
    identifier_original_rating = 'original_rating'+label['original_label']
    uri_original_rating = 'original_rating/'+uri_generator(identifier_original_rating)
    
    g.add((URIRef(prefix+uri_original_rating), RDF.type, SO.Rating))
    g.add((URIRef(prefix+uri_original_rating), SO.ratingValue, Literal(label['original_label'])))
    g.add((URIRef(prefix+uri_original_rating), SO.name, Literal(label['original_label'].replace('_', ' '))))
    
    uri_rating = 'rating/'+label['coinform_label']
    
    g.add((URIRef(prefix+uri_rating), RDF.type, SO.Rating))
    g.add((URIRef(prefix+uri_rating), SO.ratingValue, Literal(label['coinform_label'])))
    g.add((URIRef(prefix+uri_rating), SO.name, Literal(label['coinform_label'].replace('_', ' '))))
    
    g.add((URIRef(prefix+uri_original_rating), SO.sameAs, URIRef(prefix+uri_rating)))

    domains = label['domains'].split(',')
    for d in label['domains'].split(','):
        corresponding_org_website = ""
        for websites in all_organizations_websites:
            if d in websites:
                corresponding_org_website=websites
        corresponding_org_name = all_organizations_names[all_organizations_websites.index(corresponding_org_website)]
        identifier_author = 'organization'+str(corresponding_org_name)
        uri_author = 'organization/'+uri_generator(identifier_author)
        g.add((URIRef(prefix+uri_original_rating), SO.author, URIRef(prefix+uri_author)))
        
print('Done')
            
print('Nb Nodes:', len(g))
print('Saving ttl file to ../cr_data/claimreview-kg.ttl')
g.serialize(destination="../cr_data/claimreview-kg.ttl")
print('Done')
