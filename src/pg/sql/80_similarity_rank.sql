CREATE OR REPLACE FUNCTION cdb_SimilarityRank(cartodb_id numeric, query text)
returns TABLE (cartodb_id NUMERIC, similarity NUMERIC)
as $$
  from crankshaft.similarity import similarity_rank
  return similarity_rank(cartodb_id, query)
$$ LANGUAGE plpythonu

CREATE OR REPLACE FUNCTION cdb_MostSimilar(cartodb_id numeric, query text ,matches numeric)
returns TABLE (cartodb_id NUMERIC, similarity NUMERIC)
as $$
  from crankshaft.similarity import most_similar
  return most_similar(matches, query)
$$ LANGUAGE plpythonu
