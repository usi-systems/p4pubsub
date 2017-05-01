from apptopo import AppTopo

class CustomAppTopo(AppTopo):

    def __init__(self, *args, **kwargs):
        manifest, target = kwargs['manifest'], kwargs['target']

        conf = manifest['targets'][target]

        if 'routing_conf_file' in conf:
            import json
            with open(conf['routing_conf_file'], 'r') as f:
                conf['routing_conf'] = json.load(f)

        conf['links'] = conf['routing_conf']['links']
        sw_names = sorted(sum(map(list, conf['links']), []))

        conf['hosts'] = {
                "h01": {
                    "cmd": "./label_recv.py 1234",
                    "startup_sleep": 0.2,
                    "wait": False
                },
                "h02": {
                    "cmd": "./label_send.py $s01_label 10.0.2.1 1234",
                    "wait": True
                }
            }

        conf['links'] += [('h01', 's01'), ('h02', 's09')]

        AppTopo.__init__(self, *args, **kwargs)

