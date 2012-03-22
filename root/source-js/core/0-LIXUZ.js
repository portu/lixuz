(function($)
{
    window.LIXUZ = window._L = {
        namespace: function(namespace)
        {
            if(this[namespace])
            {
                return this[namespace];
            }
            else
            {
                return this.addNamespace(namespace,{});
            }
        },

        addNamespace: function(namespace,methods)
        {
            if (!this[namespace])
            {
                this[namespace] = {
                    define: this.define,
                    addNamespace: this.addNamespace,
                    extendNamespace: this.extendNamespace,
                    namespace: this.namespace
                };
            }
            return this[namespace].define(methods);
        },

        extendNamespace: function(namespace,methods)
        {
            return this.addNamespace(namespace,methods);
        },

        define: function(methods)
        {
            $.extend(this,methods);
            return this;
        }
    };

    LIXUZ.define({
        version: function()
        {
            return $('#lixuz_version').val();
        }
    });
})(jQuery);
