# ONE WORKER, DELIBERATELY. The copy loop starts inside the web process, so a
# second gunicorn worker is a second copy loop -- and two loops racing the same
# master order is every trade copied twice. The stamp at the broker would catch
# most of it, but the duplicate guarantee is not something to lean on to cover
# for a process count nobody meant to set. Threads, not workers, give this app
# its concurrency.
#
# No --preload either: with preloading, the app is imported in the master
# process and the workers are forked from it, and threads do not survive a
# fork. The pages would serve perfectly and nothing would ever copy.
web: gunicorn webapp:app --workers 1 --threads 4 --timeout 120 --log-file - --access-logfile -
